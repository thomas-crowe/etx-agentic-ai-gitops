#!/bin/bash

# Check if number of users is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <number_of_users>"
    echo "Example: $0 7"
    exit 1
fi

NUM_USERS=$1

# Validate that NUM_USERS is a positive integer
if ! [[ "$NUM_USERS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Number of users must be a positive integer"
    exit 1
fi

echo "Applying llama-stack-config.yaml to namespaces user1-llama-stack to user${NUM_USERS}"
echo "=================================================================="
echo

# Iterate over all users
for i in $(seq 1 ${NUM_USERS}); do
    USERNAME="user${i}"
    NAMESPACE="${USERNAME}-llama-stack"
    
    echo "Processing ${NAMESPACE}..."
    echo "----------------------------------------"
    
    # Check if namespace exists
    if ! oc get namespace "${NAMESPACE}" &>/dev/null; then
        echo "  Warning: Namespace ${NAMESPACE} does not exist, skipping..."
        echo
        continue
    fi
    
    # Apply the configmap YAML with namespace and username substitution
    oc apply -f - <<EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: llama-stack-config
  namespace: ${NAMESPACE}
data:
  run.yaml: |
    # Llama Stack configuration
    version: '2'
    image_name: rh
    apis:
    - inference
    - tool_runtime
    - agents
    - safety
    - vector_io
    models:
      - metadata: {}
        model_id: granite-3-2-8b-instruct
        provider_id: vllm-granite-3-2-8b-instruct
        provider_model_id: granite-3-2-8b-instruct
        model_type: llm
    providers:
      inference:
      - provider_id: vllm-granite-3-2-8b-instruct
        provider_type: "remote::vllm"
        config:
          url: https://litellm-prod.apps.maas.redhatworkshops.io/v1
          context_length: 4096
          api_token: \${env.DEFAULT_MODEL_API_TOKEN}
          tls_verify: true
      tool_runtime:
      - provider_id: tavily-search
        provider_type: remote::tavily-search
        config:
          api_key: \${env.TAVILY_API_KEY}
          max_results: 3
      - provider_id: model-context-protocol
        provider_type: remote::model-context-protocol
        config: {}
      agents:
      - provider_id: meta-reference
        provider_type: inline::meta-reference
        config:
          persistence_store:
            type: sqlite
            db_path: \${env.SQLITE_STORE_DIR:=~/.llama/distributions/rh}/agents_store.db
          responses_store:
            type: sqlite
            db_path: \${env.SQLITE_STORE_DIR:=~/.llama/distributions/rh}/responses_store.db
    server:
      port: 8321
    tools:
      - name: builtin::websearch
        enabled: true
    tool_groups:
    - provider_id: tavily-search
      toolgroup_id: builtin::websearch
    - toolgroup_id: mcp::openshift
      provider_id: model-context-protocol
      mcp_endpoint:
        uri: http://ocp-mcp-server.mcp-openshift.svc.cluster.local:8000/sse
    - toolgroup_id: mcp::github
      provider_id: model-context-protocol
      mcp_endpoint:
        uri: http://github-mcp-server:80/sse
EOF
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Successfully applied configmap to ${NAMESPACE}"
    else
        echo "  ✗ Failed to apply configmap to ${NAMESPACE}"
    fi
    echo
done

echo "=================================================================="
echo "Completed applying llama-stack-config.yaml for users 1 to ${NUM_USERS}"
echo "=================================================================="

