#!/bin/bash

#FZF_COMMON="-m --no-sort --reverse --header-lines=1 --inline-info --toggle-sort=\`"

# Tab ID completion for bruvtab close
_fzf_complete_bt() {
  ARGS="$@"
  if [[ $ARGS == 'bruvtab close'* ]] || \
        [[ $ARGS == 'bruvtab activate'* ]] || \
        [[ $ARGS == 'bruvtab text'* ]] || \
        [[ $ARGS == 'bruvtab html'* ]] || \
        [[ $ARGS == 'bruvtab words'* ]]; \
  then
    _fzf_complete --multi --no-sort --inline-info --toggle-sort=\` -- "$@" < <(
      { bruvtab list }
    )
  else
    eval "zle ${fzf_default_completion:-expand-or-complete}"
  fi
}

_fzf_complete_bt_post() {
  cut -f1 -d$'\t'
}

