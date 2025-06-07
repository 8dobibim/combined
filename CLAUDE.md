# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This is a hybrid repository containing two main components:

1. **8dobibim_back/** - Infrastructure project for deploying OpenWebUI on AWS EKS
2. **open-webui/** - Full-stack AI chat interface application (git submodule)

## 8dobibim_back Project

### Key Technologies
- **Infrastructure**: Terraform (AWS provider), Kubernetes/EKS, ArgoCD
- **Monitoring**: Prometheus, Grafana
- **Documentation**: Comprehensive Korean guides in `docs/`

### Important Configuration Files
- `terraform-related/terraform/` - Main Terraform configurations for EKS cluster
- `terraform-related/AWS_terraform_grafana/` - Grafana monitoring setup
- `argocd/` - ArgoCD application definitions
- `docs/` - Complete deployment and operational guides in Korean

### Common Commands
```bash
# Terraform operations (from terraform-related/terraform/)
terraform init
terraform plan
terraform apply
terraform destroy

# Grafana setup (from terraform-related/AWS_terraform_grafana/)
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

## open-webui Project

### Key Technologies
- **Frontend**: SvelteKit, TypeScript, TailwindCSS, Vite
- **Backend**: Python 3.11, FastAPI, uvicorn
- **AI/ML**: OpenAI, Anthropic, LangChain, ChromaDB, sentence-transformers
- **Database**: PostgreSQL, SQLite, MongoDB support
- **Testing**: Cypress (E2E), pytest (backend)

### Important Configuration Files
- `package.json` - Node.js dependencies and scripts
- `pyproject.toml` - Python project configuration
- `requirements.txt` - Python backend dependencies
- `docker-compose.yaml` - Multi-service Docker setup
- `svelte.config.js` - SvelteKit configuration
- `tailwind.config.js` - TailwindCSS styling configuration

### Development Commands

**Frontend Development:**
```bash
cd open-webui
npm install                 # Install dependencies
npm run dev                 # Start development server
npm run build              # Build for production
npm run preview            # Preview production build
npm run check              # Type checking
npm run lint               # Run linting
```

**Backend Development:**
```bash
cd open-webui/backend
pip install -r requirements.txt    # Install dependencies
./dev.sh                           # Start development server
python -m pytest                  # Run tests
```

**Docker Development:**
```bash
cd open-webui
docker-compose up -d               # Start all services
docker-compose -f docker-compose.gpu.yaml up -d  # With GPU support
```

### Architecture Overview

**Frontend (SvelteKit)**:
- `src/routes/` - Page components and routing
- `src/lib/` - Shared utilities, stores, and components
- `src/lib/apis/` - API client functions
- `src/lib/stores/` - Svelte stores for state management

**Backend (FastAPI)**:
- `backend/open_webui/routers/` - API route handlers
- `backend/open_webui/models/` - Database models
- `backend/open_webui/utils/` - Utility functions
- `backend/open_webui/internal/` - Core application logic

**Key Features**:
- Multi-LLM provider support (OpenAI, Anthropic, Ollama, etc.)
- RAG (Retrieval-Augmented Generation) with vector databases
- Real-time chat interface with WebSocket support
- File upload and processing capabilities
- User authentication and authorization
- Plugin/function system for extensibility

### Environment Configuration

The application uses environment variables for configuration. Key variables include:
- Database connections (PostgreSQL, MongoDB)
- AI provider API keys (OpenAI, Anthropic)
- Authentication settings
- File storage configuration

### Testing

**E2E Testing (Cypress)**:
```bash
npm run test:e2e           # Run Cypress tests
```

**Backend Testing**:
```bash
cd backend && python -m pytest
```

## Development Workflow

1. **Infrastructure Setup**: Use Terraform configurations in `8dobibim_back/` for AWS deployment
2. **Local Development**: Use Docker Compose for full-stack development
3. **Frontend Changes**: Work in `open-webui/src/` with hot reload via `npm run dev`
4. **Backend Changes**: Work in `open-webui/backend/` with auto-reload via `./dev.sh`
5. **Deployment**: Use ArgoCD configurations for GitOps deployment to EKS

## Important Notes

- The repository contains extensive Korean documentation in `8dobibim_back/docs/`
- open-webui is included as a git submodule
- Both projects follow modern containerization practices
- The infrastructure setup includes comprehensive monitoring with Prometheus/Grafana