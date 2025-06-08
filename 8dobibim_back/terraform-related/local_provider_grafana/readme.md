## Terraform 변수 및 파라미터 설정 가이드

이 코드는 빠른 실행을 위한 인프라 설정이 되어 있지만, 실제 서비스 구동에 필요한 **API 키**나 **마스터 비밀번호** 같은 민감한 정보는 포함하지 않습니다. 따라서, `terraform apply`를 실행하기 전에 **`tfvars.example` 파일을 참고하여** 개인화된 데이터를 포함하는 **`terraform.tfvars` 파일을 로컬에 설정**하거나 **AWS에서 필요한 정보를 추가해야 합니다.**

여기서는 제공된 `variables.tf` 파일의 내용을 바탕으로 `terraform.tfvars`에 포함될 내용을 설명해 드립니다.

### 1. `variables.tf` 파일 이해하기

`variables.tf` 파일은 Terraform 프로젝트에서 사용할 모든 변수를 정의하는 곳입니다. 각 변수는 `variable` 블록으로 선언되며, 다음과 같은 속성을 가질 수 있습니다. 

* **`description`**: 변수의 목적을 설명합니다. 명확하고 자세하게 작성하여 다른 사람이 코드를 이해하는 데 도움을 줍니다. 
* **`type`**: 변수가 어떤 종류의 값(예: `string`, `number`, `bool`, `list`, `map`)을 받을지 정의합니다. 
* **`default`**: 변수에 명시적인 값이 제공되지 않을 경우 사용될 **기본값**을 지정합니다. 개발 환경 등에서 빠르게 테스트할 때 유용합니다.
* **`sensitive`**: `true`로 설정하면 이 변수에 할당된 값이 Terraform 플랜 또는 출력에 표시되지 않도록 숨겨줍니다. **API 키, 비밀번호 등 민감한 정보에 반드시 사용해야 합니다.**

**예시 (`variables.tf` 일부):**

```terraform
variable "namespace" {
  description = "Kubernetes namespace to deploy resources into"
  type        = string
  default     = "llm-project" # 원하는 네임스페이스로 변경 가능
}

variable "litellm_master_key" {
  description = "LiteLLM Master Key for authentication/validation"
  type        = string
  sensitive   = true # 민감 정보로 마킹
}
```

### 2. `terraform.tfvars` 파일을 통한 변수 값 지정

`variables.tf`에서 변수를 선언했다면, 실제로 Terraform을 실행할 때 이 변수들에 값을 할당해야 합니다. `.tfvars` 파일은 변수 값을 저장하는 가장 일반적인 방법입니다.

프로젝트 루트에 `terraform.tfvars`라는 파일이 있다면, Terraform은 자동으로 이 파일을 로드합니다. 또는 `terraform apply -var-file="example.tfvars"`와 같이 특정 `.tfvars` 파일을 지정할 수도 있습니다.

**`terraform.tfvars` (또는 `tfvars.example`에서 복사하여 수정)**

```terraform
# --- Kubernetes 네임스페이스 설정 ---
namespace = "llm-project" # variables.tf의 default 값과 일치하거나 원하는 값으로 변경

# --- Image Versions (variables.tf에 정의된 기본값과 다르게 설정하고 싶을 경우) ---
# litellm_image = "ghcr.io/berriai/litellm:main-latest"
# openwebui_image_v1 = "ghcr.io/open-webui/open-webui:v0.6.7"
# openwebui_image_v2 = "ghcr.io/open-webui/open-webui:v0.6.6"
# prometheus_image = "prom/prometheus:v2.47.1"
# postgres_image = "postgres:13"

# --- 애플리케이션 포트 설정 ---
litellm_api_port = 4000
litellm_service_nodeport = 30001
litellm_metrics_port = 9000
openwebui_port = 8080
openwebui_service_nodeport = 30000
prometheus_port = 9090
prometheus_service_nodeport = 30090
postgres_port = 5432

# --- 민감한 환경 변수 및 자격 증명 (매우 중요: 실제 값으로 대체) ---
#이 값들은 절대로 Git 저장소에 직접 커밋해서는 안 됩니다!
#대신 `terraform apply -var="VAR_NAME=VALUE"` 또는 CI/CD 파이프라인의 시크릿 관리 기능을 사용하세요.
LITELLM_MASTER_KEY = "<YOUR_ACTUAL_LITELLM_MASTER_KEY>" # 반드시 변경 
LITELLM_SALT_KEY = "<YOUR_ACTUAL_LITELLM_SALT_KEY>"     # 반드시 변경
GEMINI_API_KEY = "<YOUR_ACTUAL_GEMINI_API_KEY>"         # 반드시 변경
AZURE_API_KEY = "<YOUR_ACTUAL_AZURE_API_KEY>"           # 반드시 변경 
AZURE_API_BASE = "https://your-azure-resource.openai.azure.com/" # 실제 Azure OpenAI Endpoint로 변경 
AZURE_API_VERSION = "2023-07-01-preview"                # 실제 API 버전으로 변경

# PostgreSQL 데이터베이스 설정
postgres_user = "<YOUR_ACTUAL_POSTGRES_USER>"           # 반드시 변경
postgres_password = "<YOUR_ACTUAL_POSTGRES_PASSWORD>"   # 반드시 변경 
postgres_db = "<YOUR_ACTUAL_POSTGRES_DB_NAME>"          # 반드시 변경 
# PostgreSQL 데이터베이스 URL (예: postgresql://user:password@host:port/db)
# main.tf에서 DATABASE_URL 변수 주입 시 사용됩니다.
DATABASE_URL = "postgresql://<YOUR_ACTUAL_POSTGRES_USER>:<YOUR_ACTUAL_POSTGRES_PASSWORD>@postgres-service:5432/<YOUR_ACTUAL_POSTGRES_DB_NAME>"
```

### 번외. `main.tf`에서의 변수 활용

만약, 정의된 변수 외 다른 변수를 활용하거나 설정을 추가하고 싶으실 땐, `variables.tf`와 `terraform.tfvars` 외에도 **`main.tf`에 대한 수정이 필요**합니다. `var.<변수명>` 형식으로 `variables.tf`에서 선언된 변수들을 참조할 수 있으며, 이 과정을 아래 예시 코드를 통해 확인해보세요.

```terraform
# Kubernetes Provider: 로컬 kubeconfig 파일 사용
provider "kubernetes" {
  config_path = "C:\\Users\\Woo\\.kube\\config" # 실제 kubeconfig 경로로 변경 필요
}

# 네임스페이스 생성
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.namespace # variables.tf의 namespace 변수 참조
  }
}

# PostgreSQL Deployment
resource "kubernetes_deployment" "postgres_deployment" {
  metadata {
    name      = "postgres"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "postgres"
      }
    }
    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }
      spec {
        container {
          name  = "postgres"
          image = var.postgres_image # variables.tf의 postgres_image 변수 참조
          port {
            container_port = var.postgres_port # variables.tf의 postgres_port 변수 참조
          }
          env_from {
            secret_ref {
              name = kubernetes_secret.app_secrets.metadata[0].name
            }
          }
          env {
            name = "STORE_MODEL_IN_DB" # STORE_MODEL_IN_DB 환경 변수 추가
            value = "True"
          }
          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }
        }
        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

# LiteLLM Deployment
resource "kubernetes_deployment" "litellm_deployment" {
  metadata {
    name      = "litellm"
    namespace = var.namespace
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/path"   = "/metrics"
      "prometheus.io/port"   = "${var.litellm_metrics_port}" # variables.tf의 litellm_metrics_port 변수 참조
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "litellm"
      }
    }
    template {
      metadata {
        labels = {
          app = "litellm"
        }
      }
      spec {
        container {
          name  = "litellm"
          image = var.litellm_image # variables.tf의 litellm_image 변수 참조
          args = [
            "--config", "/app/config/config.yaml",
            "--host", "0.0.0.0",
            "--port", "${var.litellm_api_port}", # variables.tf의 litellm_api_port 변수 참조
            "--telemetry", "False"
          ]
          port {
            name = "api"
            container_port = var.litellm_api_port 
          }
          port {
            name = "metrics"
            container_port = var.litellm_metrics_port 
          }
          env_from {
            secret_ref {
              name = kubernetes_secret.app_secrets.metadata[0].name 
            }
          }
          volume_mount {
            name       = "litellm-config-volume"
            mount_path = "/app/config"
          }
        }
        volume {
          name = "litellm-config-volume"
          config_map {
            name = kubernetes_config_map.litellm_config.metadata[0].name
            items {
              key  = "config.yaml"
              path = "config.yaml"
            }
          }
        }
      }
    }
  }
}

# OpenWebUI Deployment (Version 1)
resource "kubernetes_deployment" "openwebui_deployment_v1" {
  metadata {
    name      = "openwebui-v1"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app     = "openwebui"
        version = "v1"
      }
    }
    template {
      metadata {
        labels = {
          app     = "openwebui"
          version = "v1"
        }
      }
      spec {
        container {
          name  = "openwebui"
          image = var.openwebui_image_v1 # variables.tf의 openwebui_image_v1 변수 참조
          port {
            container_port = var.openwebui_port
          }
          env{
            name = "DEFAULT_MODELS"
            value = "gemini-2.0-flash"
          }
          env {
            name = "OPENAI_API_BASE_URL"
             value = "http://litellm-service:${var.litellm_api_port}"
          }
          env {
            name = "OPENAI_API_KEY"
            value = "dummy-key"
          }
        }
      }
    }
  }
}

# OpenWebUI Deployment (Version 2)
resource "kubernetes_deployment" "openwebui_deployment_v2" {
  metadata {
    name      = "openwebui-v2"
     namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app     = "openwebui"
        version = "v2"
      }
    }
    template {
      metadata {
        labels = {
          app     = "openwebui"
           version = "v2" 
        }
      }
      spec {
        container {
          name  = "openwebui"
           image = var.openwebui_image_v2 # variables.tf의 openwebui_image_v2 변수 참조
          port {
             container_port = var.openwebui_port
          }
          env{
            name = "DEFAULT_MODELS"
            value = "gemini-2.0-flash"
          }
          env {
            name = "OPENAI_API_BASE_URL"
             value = "http://litellm-service:${var.litellm_api_port}"
          }
          env {
            name = "OPENAI_API_KEY"
            value = "dummy-key"
          }
        }
      }
    }
  }
}

# Prometheus Deployment
resource "kubernetes_deployment" "prometheus_deployment" {
  metadata {
    name      = "prometheus"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "prometheus"
      }
    }
    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }
      spec {
        container {
          name  = "prometheus"
           image = var.prometheus_image # variables.tf의 prometheus_image 변수 참조
          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--web.console.libraries=/usr/share/prometheus/console_libraries",
            "--web.console.templates=/usr/share/prometheus/consoles"
          ]
          port {
             container_port = var.prometheus_port
          }
          volume_mount {
            name       = "prometheus-config-volume"
            mount_path = "/etc/prometheus"
          }
        }
        volume {
          name = "prometheus-config-volume"
          config_map {
             name = kubernetes_config_map.prometheus_config.metadata[0].name
          }
        }
      }
    }
  }
}

# PostgreSQL Service (ClusterIP)
resource "kubernetes_service" "postgres_service" {
  metadata {
    name      = "postgres-service"
     namespace = var.namespace
  }
  spec {
    selector = {
      app = kubernetes_deployment.postgres_deployment.spec[0].selector[0].match_labels.app
    }
    port {
      protocol    = "TCP"
       port        = var.postgres_port 
       target_port = var.postgres_port 
    }
    type = "ClusterIP"
  }
}

# LiteLLM Service (NodePort)
resource "kubernetes_service" "litellm_service" {
  metadata {
    name      = "litellm-service"
     namespace = var.namespace 
  }
  spec {
    selector = {
      app = kubernetes_deployment.litellm_deployment.spec[0].selector[0].match_labels.app
    }
    port {
      name = "api"
      protocol    = "TCP"
       port        = var.litellm_api_port
       target_port = var.litellm_api_port
       node_port   = var.litellm_service_nodeport
    }
    port {
      name = "metrics"
      protocol    = "TCP"
       port        = var.litellm_metrics_port
       target_port = var.litellm_metrics_port
    }
    type = "NodePort"
  }
}

# OpenWebUI Service (NodePort)
resource "kubernetes_service" "openwebui_service" {
  metadata {
    name      = "openwebui-service"
     namespace = var.namespace
  }
  spec {
    selector = {
       app = "openwebui"
    }
    port {
      protocol    = "TCP"
       port        = var.openwebui_port 
       target_port = var.openwebui_port 
       node_port   = var.openwebui_service_nodeport
    }
    type = "NodePort"
  }
}

# Prometheus Service (NodePort)
resource "kubernetes_service" "prometheus_service" {
  metadata {
    name      = "prometheus-service"
     namespace = var.namespace 
  }
  spec {
    selector = {
      app = kubernetes_deployment.prometheus_deployment.spec[0].selector[0].match_labels.app
    }
    port {
      protocol    = "TCP"
       port        = var.prometheus_port
       target_port = var.prometheus_port
       node_port   = var.prometheus_service_nodeport
    }
    type = "NodePort"
  }
}
```
