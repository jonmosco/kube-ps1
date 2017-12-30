Kubernetes prompt for bash and zsh
==================================

A Kubernetes (k8s) bash and zsh prompt that displays the current cluster
context and namespace.

Inspired by several tools used to simplify usage of kubectl

![prompt](img/screenshot.png)

![prompt2](img/screenshot-img.png)

![prompt demo](img/kube-ps1.gif)

## Requirements

The default prompt assumes you have the kubectl command line utility installed.
It can be obtained here:

[Install and Set up kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

If using this with OpenShift, the oc tool needs installed.  It can be obtained from here:

[OC Client Tools](https://www.openshift.org/download.html)

## Helper utilities

There are several great tools that make using kubectl very enjoyable.

[kubectx and kubenx](https://github.com/ahmetb/kubectx) are great for
fast switching between clusters and namespaces.

## Prompt Structure

The prompt layout is:

```
(<logo>|<cluster>:<namespace>)
```

## Install

1. Clone this repository
2. Source the kube-ps1.sh in your ~./.zshrc or your ~/.bashrc

ZSH:
```
source path/kube-ps1.sh zsh
PROMPT='$(kube_ps1) '
```

Bash:
```
source path/kube-ps1.sh bash
PS1='[\u@\h \W\[$(kube_ps1)\]]\$ '
```

NOTE: The argument when sourcing is the shell being used.

## Colors

The colors are of my opinion. Blue was used as the prefix to match the Kubernetes
color as closely as possible. Red was chosen as the cluster name to stand out, and cyan
for the namespace.  These can of course be changed.

## Customization

The default settings can be overridden in ~/.bashrc or ~/.zshrc

| Variable | Default | Meaning |
| :------- | :-----: | ------- |
| `KUBE_PS1_DEFAULT` | `true` | Default settings for the prompt |
| `KUBE_PS1_PREFIX` | `(` | Prompt opening character  |
| `KUBE_PS1_DEFAULT_LABEL` | `⎈ ` | Default prompt symbol |
| `KUBE_PS1_SEPERATOR` | `\|` | Separator between symbol and cluster name |
| `KUBE_PS1_PLATFORM` | `kubectl` | Cluster type and binary to use |
| `KUBE_PS1_DIVIDER` | `:` | Separator between cluster and namespace |
| `KUBE_PS1_SUFFIX` | `)` | Prompt closing character |
| `KUBE_PS1_DEFAULT_LABEL_IMG` | `false` | Use Kubernetes img as the label: ☸️  |

## Contributors

Jared Yanovich
