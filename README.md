Kubernetes prompt for bash and zsh
==================================

A Kubernetes (k8s) bash and zsh prompt that displays the current cluster
context and the namespace.

Inspired by several tools used to simplify usage of kubectl

![prompt](img/screenshot.png)

## Requirements

This prompt assumes you have the kubectl command line utility installed.  It
can be obtained here:

[Install and Set up kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Prompt Structure

The prompt layout is:

```
(k8s|<cluster>:<namespace>)
```

## Install

1. Clone this repository
2. Source the kube-prompt.sh in your ~./.zshrc or your ~/.bashrc

ZSH:
```
source path/kube-prompt.sh
PROMPT='$(kube_prompt)'
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
