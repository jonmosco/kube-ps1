Kubernetes prompt for bash and zsh
==================================

A Kubernetes (k8s) bash and zsh prompt that displays the current cluster
context and the namespace.

Inspired by several tools used to simplify usage of kubectl

![prompt](img/screenshot2.png)

## Requirements

The default prompt assumes you have the kubectl command line utility installed.  It
can be obtained here:

[Install and Set up kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

If using this with OpenShift, the oc tool needs installed.  It can be obtained from here:

[OC Client Tools](https://www.openshift.org/download.html)

## Prompt Structure

The prompt layout is:

```
(<platform>|<cluster>:<namespace>)
```

Supported platforms:
* k8s - Kubernetes
* ocp - OpenShift

## Install

1. Clone this repository
2. Source the kube-prompt.sh in your ~./.zshrc or your ~/.bashrc

ZSH:
```
source path/kube-prompt.sh
PROMPT='$(kube_prompt) '
```

Bash:
```
source path/kube-prompt.sh
PS1='[\u@\h \W$(kube_prompt)]\$ '
```

## Colors

The colors are of my opinion.  Blue was used as the prefix indicating the
prompts function.  Red was chosen as the cluster name to stand out, and cyan
for the namespace.  These can of course be changed.

## Customization

The default settings can be overriden in ~/.bashrc or ~/.zshrc

| Variable | Default | Meaning |
| :------- | :-----: | ------- |
| `KUBE_PROMPT_DEFAULT` | `true` | Default settings for the prompt |
| `KUBE_PROMPT_PREFIX` | `(` | Prompt opening character  |
| `KUBE_PROMPT_DEFAULT_LABEL` | `⎈` | Keep the default prompt symbol |
| `KUBE_PROMPT_SEPERATOR` | `|` | Seperator between symbol and cluster name |
| `KUBE_PROMPT_PLATFORM` | `kubectl` | Cluster type and binary to use |
| `KUBE_PROMPT_DIVIDER` | `:` | Seperator between cluster and namespace |
| `KUBE_PROMPT_SUFFIX` | `)` | Prompt closing character |
| `KUBE_PROMPT_DEFAULT_LABEL_IMG` | `false` | Use Kubernetes img as the label: ☸️  |
