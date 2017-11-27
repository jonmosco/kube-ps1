kube_prompt () {
  K8S_PROMPT_PREFIX="("
  K8S_PROMPT_SUFFIX=")"
  K8S_PROMPT_SEPARATOR="|"
  K8S_PROMPT_LABEL="%F{blue}k8s"
  K8S_PROMPT_CLUSTER="%f%F{161}$(kubectl config view --minify  --output 'jsonpath={..CurrentContext}')"
  K8S_PROMPT_NAMESPACE="%f%F{161}$(kubectl config view --minify  --output 'jsonpath={..namespace}')"
  K8S_PROMPT="$K8S_PROMPT_PREFIX$K8S_PROMPT_LABEL%{${reset_color}%}$K8S_PROMPT_SEPARATOR$K8S_PROMPT_CLUSTER%{${reset_color}%}:$K8S_PROMPT_NAMESPACE%{${reset_color}%}$K8S_PROMPT_SUFFIX"
  echo $K8S_PROMPT
}
