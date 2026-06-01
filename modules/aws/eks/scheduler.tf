# ──────────────────────────────────────────────────────────────────────────────
# EKS Node Scheduler — Lambda + EventBridge
# Escala los node groups a 0 en horario de inactividad y los restaura en
# horario de trabajo. Las horas se definen en UTC en el tfvars.
# ──────────────────────────────────────────────────────────────────────────────

locals {
  scheduler_clusters = {
    for k, v in var.eks : k => v
    if try(v.node_scheduler.enabled, false)
  }
}

# ── Código Python inline (no requiere fichero externo) ───────────────────────

data "archive_file" "scheduler_lambda" {
  for_each = local.scheduler_clusters

  type        = "zip"
  output_path = "${path.module}/generated/scheduler_${each.key}.zip"

  source {
    filename = "scheduler.py"
    content  = <<-PYTHON
import boto3
import json
import os

def lambda_handler(event, context):
    eks_client = boto3.client("eks", region_name=os.environ["AWS_REGION"])
    cluster_name  = os.environ["CLUSTER_NAME"]
    action        = event.get("action", "scale_down")
    node_groups   = json.loads(os.environ["NODE_GROUPS_CONFIG"])

    results = []
    for ng in node_groups:
        if action == "scale_down":
            config = {"minSize": 0, "maxSize": ng["max"], "desiredSize": 0}
        else:
            config = {
                "minSize":     ng["min"],
                "maxSize":     ng["max"],
                "desiredSize": ng["desired"],
            }
        eks_client.update_nodegroup_config(
            clusterName  = cluster_name,
            nodegroupName= ng["name"],
            scalingConfig= config,
        )
        results.append({"nodegroup": ng["name"], "action": action, "config": config})

    print(json.dumps({"cluster": cluster_name, "results": results}))
    return {"statusCode": 200, "results": results}
PYTHON
  }
}

# ── IAM role para la Lambda ───────────────────────────────────────────────────

resource "aws_iam_role" "scheduler_lambda" {
  for_each = local.scheduler_clusters

  name = "${var.name_prefix}-${each.key}-node-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}-node-scheduler" })
}

resource "aws_iam_role_policy" "scheduler_lambda_eks" {
  for_each = local.scheduler_clusters

  name = "eks-nodegroup-scaling"
  role = aws_iam_role.scheduler_lambda[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:UpdateNodegroupConfig",
          "eks:DescribeNodegroup",
        ]
        Resource = "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:nodegroup/${var.name_prefix}-${each.key}/*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
      }
    ]
  })
}

# ── Lambda function ───────────────────────────────────────────────────────────

resource "aws_lambda_function" "node_scheduler" {
  for_each = local.scheduler_clusters

  function_name    = "${var.name_prefix}-${each.key}-node-scheduler"
  role             = aws_iam_role.scheduler_lambda[each.key].arn
  filename         = data.archive_file.scheduler_lambda[each.key].output_path
  source_code_hash = data.archive_file.scheduler_lambda[each.key].output_base64sha256
  handler          = "scheduler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      CLUSTER_NAME       = var.name_prefix != "" ? "${var.name_prefix}-${each.key}" : each.key
      NODE_GROUPS_CONFIG = jsonencode([
        for ng_name, ng_cfg in try(each.value.compute.workload_node_groups, {}) : {
          name    = ng_name
          min     = try(ng_cfg.min_size, 1)
          max     = try(ng_cfg.max_size, 4)
          desired = try(ng_cfg.desired_size, 2)
        }
      ])
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}-node-scheduler" })

  depends_on = [aws_iam_role_policy.scheduler_lambda_eks]
}

# ── EventBridge rules ─────────────────────────────────────────────────────────

resource "aws_cloudwatch_event_rule" "scale_down" {
  for_each = local.scheduler_clusters

  name                = "${var.name_prefix}-${each.key}-scale-down"
  description         = "Escala nodos EKS a 0 (horario UTC: ${each.value.node_scheduler.scale_down_cron_utc})"
  schedule_expression = "cron(${each.value.node_scheduler.scale_down_cron_utc})"
  state               = "ENABLED"

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}-scale-down" })
}

resource "aws_cloudwatch_event_rule" "scale_up" {
  for_each = local.scheduler_clusters

  name                = "${var.name_prefix}-${each.key}-scale-up"
  description         = "Restaura nodos EKS (horario UTC: ${each.value.node_scheduler.scale_up_cron_utc})"
  schedule_expression = "cron(${each.value.node_scheduler.scale_up_cron_utc})"
  state               = "ENABLED"

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}-scale-up" })
}

resource "aws_cloudwatch_event_target" "scale_down" {
  for_each = local.scheduler_clusters

  rule      = aws_cloudwatch_event_rule.scale_down[each.key].name
  target_id = "scale-down-lambda"
  arn       = aws_lambda_function.node_scheduler[each.key].arn
  input     = jsonencode({ action = "scale_down" })
}

resource "aws_cloudwatch_event_target" "scale_up" {
  for_each = local.scheduler_clusters

  rule      = aws_cloudwatch_event_rule.scale_up[each.key].name
  target_id = "scale-up-lambda"
  arn       = aws_lambda_function.node_scheduler[each.key].arn
  input     = jsonencode({ action = "scale_up" })
}

resource "aws_lambda_permission" "allow_eventbridge_scale_down" {
  for_each = local.scheduler_clusters

  statement_id  = "AllowEventBridgeScaleDown"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.node_scheduler[each.key].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scale_down[each.key].arn
}

resource "aws_lambda_permission" "allow_eventbridge_scale_up" {
  for_each = local.scheduler_clusters

  statement_id  = "AllowEventBridgeScaleUp"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.node_scheduler[each.key].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scale_up[each.key].arn
}
