# Changelog

## [1.1.0](https://github.com/jdmonsalvel/tfm-terraform-framework/compare/v1.0.11...v1.1.0) (2026-06-03)


### Features

* **backend:** replace hardcoded backend.tf with dynamic setup script ([9a05b81](https://github.com/jdmonsalvel/tfm-terraform-framework/commit/9a05b81a605b198b54480f5f703af96a42976345))
* **bootstrap:** activar bootstrap Terraform + ingress-nginx como addon gestionado ([9767e4e](https://github.com/jdmonsalvel/tfm-terraform-framework/commit/9767e4e05b8134fc26118bec6a0fa496f38f18e8))
* **cloudflare:** módulo DNS + fix local-exec working_dir en bootstrap ([6223fbe](https://github.com/jdmonsalvel/tfm-terraform-framework/commit/6223fbe0e98e8f55153c66bedca7effc43fc5fa7))
* **eks:** add node scheduler and fix LBC IRSA permissions ([c0f7172](https://github.com/jdmonsalvel/tfm-terraform-framework/commit/c0f717229e978f439799a4d07ebbe0b15ef048fc))
* **eks:** add scripts/bootstrap.sh — configures kubectl, GitOps mode ([028db88](https://github.com/jdmonsalvel/tfm-terraform-framework/commit/028db88f89c415b6f376557d61c65c9934b10fde))


### Bug Fixes

* **eks:** cluster_region usa var.region — evita deprecación data.aws_region.current ([0c5c6c0](https://github.com/jdmonsalvel/tfm-terraform-framework/commit/0c5c6c0eacf234524983cae529efb6fa61a7f0d7))
* **eks:** cluster_tools_node_group default null en var.eks.compute — elimina m7i.large ([965a682](https://github.com/jdmonsalvel/tfm-terraform-framework/commit/965a682631f1c5608dc9adc321ae2550c2969347))
* **eks:** cluster_tools_node_group fallback null — evita node group no solicitado ([c1b89bd](https://github.com/jdmonsalvel/tfm-terraform-framework/commit/c1b89bd9ec542c0f633c77348b494023522e4d9e))
* **eks:** data.aws_region.current.name + bootstrap.sh resiliente a endpoint privado ([87b7d2f](https://github.com/jdmonsalvel/tfm-terraform-framework/commit/87b7d2faf89fb0da294114832014ce2981b192f5))
* **eks:** pasar var.region al módulo EKS — evita dependencia de data.aws_region deprecated ([3f64f47](https://github.com/jdmonsalvel/tfm-terraform-framework/commit/3f64f47991d701b13b7a5063c4dbf93be49e3193))
