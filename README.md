kube-ps1: Kubernetes prompt for bash and zsh
============================================

A script that lets you add the current Kubernetes context and namespace configured
on `kubectl` to your Bash/Zsh prompt strings (i.e. the `$PS1`).

Inspired by several tools used to simplify usage of `kubectl`.

![prompt](img/screenshot.png)

![prompt2](img/screenshot-img.png)

![prompt demo](img/kube-ps1.gif)

## Installing

1. Clone this repository
2. Source the kube-ps1.sh in your `~/.zshrc` or your ~/.bashrc

For Zsh:
```sh
source /path/to/kube-ps1.sh
PROMPT='$(kube_ps1)'$PROMPT
```

For Bash:
```sh
source /path/to/kube-ps1.sh
PS1="[\u@\h \W \[$(kube_ps1)\]]\$ "
```

## Requirements

The default prompt assumes you have the `kubectl` command line utility installed.
It can be obtained here:

[Install and Set up kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

If using this with OpenShift, the `oc` tool needs installed.  It can be obtained from here:

[OC Client Tools](https://www.openshift.org/download.html)

## Helper utilities

There are several great tools that make using kubectl very enjoyable:

- [`kubectx` and `kubens`](https://github.com/ahmetb/kubectx) are great for
fast switching between clusters and namespaces.

## Prompt Structure

The prompt layout is:

```
(<logo>|<cluster>:<namespace>)
```

## Enabling/Disabling

If you want to stop showing Kubernetes status on your prompt string temporarily
run `kubeoff`. You can enable it again by running `kubeon`.

## Customization

The default settings can be overridden in `~/.bashrc` or `~/.zshrc` by setting
the following environment variables:

| Variable | Default | Meaning |
| :------- | :-----: | ------- |
| `KUBE_PS1_BINARY_DEFAULT` | `true` | Set default binary to `kubectl` |
| `KUBE_PS1_BINARY` | `kubectl` | Cluster type and binary to use |
| `KUBE_PS1_NS_ENABLE` | `true` | Display the namespace |
| `KUBE_PS1_PREFIX` | `(` | Prompt opening character  |
| `KUBE_PS1_LABEL_ENABLE` | `true ` | Display the prompt symbol |
| `KUBE_PS1_LABEL_DEFAULT` | `⎈ ` | Default prompt symbol |
| `KUBE_PS1_LABEL_USE_IMG` | `false` | Use Kubernetes img as the label: ☸️  |
| `KUBE_PS1_SEPARATOR` | `\|` | Separator between symbol and cluster name |
| `KUBE_PS1_DIVIDER` | `:` | Separator between cluster and namespace |
| `KUBE_PS1_SUFFIX` | `)` | Prompt closing character |

## Colors

The colors are of my opinion. Blue was used for the label to match the Kubernetes
color as closely as possible. Red was chosen as the cluster name to stand out,
and cyan for the namespace.  These can of course be changed:

| Variable | Default | Meaning |
| :------- | :-----: | ------- |
| `KUBE_PS1_LABEL_COLOR` | `blue` | Set default color of the k8s image |
| `KUBE_PS1_CTX_COLOR` | `red` | Set default color of the cluster context |
| `KUBE_PS1_NS_COLOR` | `cyan` | Set default color of the cluster namespace |

## Contributors

* [Ahmet Alp Balkan](https://github/com/ahmetb)
* Jared Yanovich
