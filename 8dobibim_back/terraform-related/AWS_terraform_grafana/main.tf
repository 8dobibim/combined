provider "aws" {
  region  = var.aws_region
  profile = "llm"
}

data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

provider "kubernetes" {
  alias                  = "eks"
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
  
}


resource "aws_vpc" "main" {
  cidr_block = "10.38.0.0/16"

  tags = {
    Name = "llm-project-eks-vpc"
  }
}
resource "aws_subnet" "subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.38.1.0/24"
  availability_zone = "ap-northeast-2b"
  map_public_ip_on_launch = true
  tags = {
    Name = "llm-subnet-1"
  }
}

resource "aws_subnet" "subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.38.2.0/24"
  availability_zone = "ap-northeast-2c"
  map_public_ip_on_launch = true
  tags = {
    Name = "llm-subnet-2"
  }
}
resource "aws_security_group_rule" "allow_openwebui_grafana" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3001
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster_sg.id
}

resource "aws_security_group_rule" "allow_prometheus" {
  type              = "ingress"
  from_port         = 9090
  to_port           = 9090
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster_sg.id
}



resource "aws_security_group" "eks_cluster_sg" {
  name        = "llm-project-eks-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.38.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_iam_role" "eks_cluster_role" {
  name = "llm-project-eks-eks-cluster-role-v3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "llm-project-eks-igw"
  }
}

# Route Table 추가
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "llm-project-eks-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "subnet_1" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet_2" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.main.id
}
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = var.private_subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  kubernetes_network_config {
    service_ipv4_cidr = "172.20.0.0/16"
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

resource "aws_iam_role" "eks_node_role" {
  name = "llm-project-eks-eks-node-role-v3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}
resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.eks_node_role.name
}
resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids = var.private_subnet_ids
  instance_types = [var.instance_type]
  
  scaling_config {
    desired_size = var.node_group_desired_capacity
    min_size     = var.node_group_min_capacity
    max_size     = var.node_group_max_capacity
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
    aws_iam_role_policy_attachment.ebs_csi_policy
  ]
}
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"
  
  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role_policy_attachment.ebs_csi_policy
  ]
}
# 이후 모든 kubernetes_* 리소스는 아래와 같이 공통적으로 추가:
# depends_on = [aws_eks_node_group.nodes]
# 예시:
resource "kubernetes_persistent_volume_claim" "postgres_pvc" {
  provider   = kubernetes.eks
  depends_on = [
    aws_eks_node_group.nodes,
    aws_eks_addon.ebs_csi_driver
  ]

  metadata {
    name      = "postgres-pvc"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = { storage = "5Gi" }
    }
    storage_class_name = "gp2-immediate"
  }
}

resource "kubernetes_service" "litellm_service" {
  provider   = kubernetes.eks
  depends_on = [aws_eks_node_group.nodes]

  metadata {
    name      = "litellm-service"
    namespace = var.namespace
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"    = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"  = "internet-facing"
    }
  }
  spec {
    selector = {
      app = "litellm"
    }
    port {
      name        = "api"
      protocol    = "TCP"
      port        = var.litellm_api_port
      target_port = var.litellm_api_port
    }
    port {
      name        = "metrics"
      protocol    = "TCP"
      port        = var.litellm_metrics_port
      target_port = var.litellm_metrics_port
    }
    type = "LoadBalancer"
  }
}

resource "kubernetes_service" "openwebui_service" {
  provider = kubernetes.eks
  depends_on = [aws_eks_node_group.nodes]

  metadata {
    name      = "openwebui-service"
    namespace = var.namespace
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"    = "classic"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"  = "internet-facing"
    }
  }
  spec {
    selector = {
      app = "openwebui"
    }
    port {
      protocol    = "TCP"
      port        = var.openwebui_port
      target_port = var.openwebui_port
    }
    type = "LoadBalancer"
  }
}

resource "kubernetes_service" "prometheus_service" {
  provider   = kubernetes.eks
  depends_on = [aws_eks_node_group.nodes]

  metadata {
    name      = "prometheus-service"
    namespace = var.namespace
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"    = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"  = "internet-facing"
    }
  }
  spec {
    selector = {
      app = "prometheus"
    }
    port {
      protocol    = "TCP"
      port        = var.prometheus_port
      target_port = var.prometheus_port
    }
    type = "LoadBalancer"
  }
}

resource "kubernetes_service" "grafana_service" {
  provider   = kubernetes.eks
  depends_on = [aws_eks_node_group.nodes]

  metadata {
    name      = "grafana-service"
    namespace = var.namespace
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"    = "classic"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"  = "internet-facing"
    }
  }
  spec {
    selector = {
      app = "grafana"
    }
    port {
      protocol    = "TCP"
      port        = var.grafana_port
      target_port = var.grafana_port
    }
    type = "LoadBalancer"
  }
}

resource "kubernetes_deployment" "litellm_deployment" {
  provider   = kubernetes.eks
  depends_on = [aws_eks_node_group.nodes]

  metadata {
    name      = "litellm"
    namespace = var.namespace
    labels = {
      app = "litellm"
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
          image = "ghcr.io/berriai/litellm:main"
                    
          env {
            name  = "AZURE_API_KEY"
            value = var.AZURE_API_KEY
          }
          env {
            name  = "AZURE_OPENAI_API_KEY"
            value = var.AZURE_API_KEY
          }
          env {
            name  = "AZURE_API_BASE"
            value = var.AZURE_API_BASE
          }
          env {
            name  = "AZURE_API_VERSION"
            value = var.AZURE_API_VERSION
          }
          env {
            name  = "GEMINI_API_KEY"  # 추가
            value = var.GEMINI_API_KEY
          }
          env {
            name  = "DATABASE_URL"
            value = var.database_url
          }
          env {
            name  = "LITELLM_MASTER_KEY"
            value = var.litellm_master_key
          }
          env {
            name  = "LITELLM_SALT_KEY"
            value = var.litellm_salt_key
          }
          port {
            container_port = var.litellm_api_port
          }
          port {
            container_port = var.litellm_metrics_port
          }
        }
      }
    }
  }
}
resource "kubernetes_deployment" "openwebui_deployment" {
  provider   = kubernetes.eks
  depends_on = [aws_eks_node_group.nodes]

  metadata {
    name      = "openwebui"
    namespace = var.namespace
    labels = {
      app = "openwebui"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "openwebui"
      }
    }
    template {
      metadata {
        labels = {
          app = "openwebui"
        }
      }
      spec {
        container {
          name  = "openwebui"
          image = "ghcr.io/open-webui/open-webui:main"
          command: ["uvicorn", "open_webui.main:app", "--host", "0.0.0.0", "--port", "3000"]
          env {
            name  = "DATABASE_URL"
            value = var.database_url
          }
          env {
            name  = "LITELLM_PROXY_BASE_URL"
            value = "http://litellm-service:${var.litellm_api_port}"
          }
          port {
            container_port = var.openwebui_port
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "prometheus_deployment" {
  provider   = kubernetes.eks
  depends_on = [aws_eks_node_group.nodes]

  metadata {
    name      = "prometheus"
    namespace = var.namespace
    labels = {
      app = "prometheus"
    }
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
          image = "prom/prometheus:latest"
          port {
            container_port = var.prometheus_port
          }
        }
      }
    }
  }
}
resource "kubernetes_deployment" "postgres_deployment" {
  provider   = kubernetes.eks
  depends_on = [
    aws_eks_node_group.nodes,
    kubernetes_persistent_volume_claim.postgres_pvc  # PVC 의존성 명시적 추가
  ]

  metadata {
    name      = "postgres"
    namespace = var.namespace
    labels = {
      app = "postgres"
    }
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
          image = "postgres:13"

          env {
            name  = "POSTGRES_DB"
            value = var.postgres_db
          }
          env {
            name  = "POSTGRES_USER"
            value = var.postgres_user
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = var.postgres_password
          }
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"  # 서브디렉토리 사용
          }
          port {
            container_port = 5432
          }

          volume_mount {
            mount_path = "/var/lib/postgresql/data"
            name       = "postgres-storage"
          }
        }

        volume {
          name = "postgres-storage"

          persistent_volume_claim {
            claim_name = "postgres-pvc"  # 직접 이름으로 참조 (더 안전)
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "postgres_service" {
  provider   = kubernetes.eks
  depends_on = [aws_eks_node_group.nodes]

  metadata {
    name      = "postgres-service"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      port        = 5432
      target_port = 5432
    }

    type = "ClusterIP"
  }
}


resource "kubernetes_deployment" "grafana_deployment" {
  provider   = kubernetes.eks
  depends_on = [aws_eks_node_group.nodes]

  metadata {
    name      = "grafana"
    namespace = var.namespace
    labels = {
      app = "grafana"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "grafana"
      }
    }
    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }
      spec {
        container {
          name  = "grafana"
          image = "grafana/grafana:latest"
          port {
            container_port = var.grafana_port
          }
        }
      }
    }
  }
}

