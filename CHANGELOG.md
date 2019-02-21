### kube-ps1 project CHANGELOG

## (UNRELEASED)

### IMPROVEMENTS

## 0.7.0 (2/21/19)

* Merged ([#47](https://github.com/jonmosco/kube-ps1/pull/47)) to allow modification of cluster and namespace with user
  supplied functions
* Color handling now takes named arguments properly for base colors and integer
  values for 256 colors

### BUG FIXES:

* For zsh, stat module is loaded with `zmodload -F zsh/stat b:zstat` to avoid
  conflict with system or user `stat`

## 0.6.0 (2/25/18)

### BUG FIXES:

* kubeon and kubeoff: Fix state on already running shells  ([#37](https://github.com/jonmosco/kube-ps1/issues/37))
