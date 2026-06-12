#!/bin/bash
# Sample Time MCP Server - Build, Push, and Deploy
#
# Builds the Docker image, pushes it to ECR, and deploys to the mcp-gateway
# namespace as a Deployment + Service. This is the backend MCP server that we
# register with the MCP Gateway Registry to test end-to-end routing.
#
# Prerequisites:
#   1. Docker installed and running
#   2. AWS CLI configured with ECR access
#   3. kubectl pointed at the EKS cluster
#
# Usage:
#   ./build-and-deploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
IMAGE_NAME="sample-time-server"
VERSION="${VERSION:-0.1.0}"
AWS_REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || echo us-west-2)}"
NAMESPACE="${NAMESPACE:-mcp-gateway}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Sample Time MCP Server - Build & Deploy"
echo "========================================"
echo "Image:     ${IMAGE_NAME}:${VERSION}"
echo "Region:    ${AWS_REGION}"
echo "Namespace: ${NAMESPACE}"

# Build the image
echo ""
echo -e "${YELLOW}Building Docker image...${NC}"
docker build \
    --platform linux/amd64 \
    -t "${IMAGE_NAME}:${VERSION}" \
    -t "${IMAGE_NAME}:latest" \
    "${SCRIPT_DIR}"

echo "Local build complete: ${IMAGE_NAME}:${VERSION}"

# Push to ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPO="${ECR_REGISTRY}/${IMAGE_NAME}"

echo ""
echo "Ensuring ECR repository exists..."
aws ecr describe-repositories --repository-names "${IMAGE_NAME}" --region "${AWS_REGION}" 2>/dev/null || \
    aws ecr create-repository \
        --repository-name "${IMAGE_NAME}" \
        --region "${AWS_REGION}" \
        --image-scanning-configuration scanOnPush=true

echo "Logging into ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | \
    docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "Pushing to ECR..."
docker tag "${IMAGE_NAME}:${VERSION}" "${ECR_REPO}:${VERSION}"
docker push "${ECR_REPO}:${VERSION}"

echo ""
echo -e "${GREEN}Push complete: ${ECR_REPO}:${VERSION}${NC}"

# Deploy to the cluster
echo ""
echo -e "${YELLOW}Deploying to ${NAMESPACE}...${NC}"
sed "s|IMAGE_PLACEHOLDER|${ECR_REPO}:${VERSION}|g" "${SCRIPT_DIR}/k8s.yaml" | \
    kubectl apply -f -

kubectl rollout status deployment/sample-time-server -n "${NAMESPACE}" --timeout=180s

echo ""
echo -e "${GREEN}========================================"
echo "Deploy complete!"
echo "========================================${NC}"
echo "In-cluster endpoint:"
echo "  http://sample-time-server.${NAMESPACE}.svc.cluster.local:8000/mcp"
