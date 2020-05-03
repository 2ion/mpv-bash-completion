#!/usr/bin/env bash
# mpv bash completion
# Generated for: %%MPV_VERSION%%

declare _mpv_use_media_globexpr=${_mpv_use_media_globexpr:-0}
declare _mpv_media_globexpr='@(mp?(e)g|MP?(E)G|wm[av]|WM[AV]|avi|AVI|asf|ASF|vob|VOB|bin|BIN|dat|DAT|vcd|VCD|ps|PS|pes|PES|fl[iv]|FL[IV]|fxm|FXM|viv|VIV|rm?(j)|RM?(J)|ra?(m)|RA?(M)|yuv|YUV|mov|MOV|qt|QT|mp[234]|MP[234]|m4[av]|M4[AV]|og[gmavx]|OG[GMAVX]|w?(a)v|W?(A)V|dump|DUMP|mk[av]|MK[AV]|m4a|M4A|aac|AAC|m[24]v|M[24]V|dv|DV|rmvb|RMVB|mid|MID|t[ps]|T[PS]|3g[p2]|3gpp?(2)|mpc|MPC|flac|FLAC|vro|VRO|divx|DIVX|aif?(f)|AIF?(F)|m2t?(s)|M2T?(S)|vdr|VDR|xvid|XVID|ape|APE|gif|GIF|nut|NUT|bik|BIK|webm|WEBM|amr|AMR|awb|AWB|iso|ISO|opus|OPUS)?(.part)'
declare -A _mpv_cache_t
declare -A _mpv_object_args_t
declare -A _mpv_object_args_param_t

#######################################################################
# lookup table loading
#######################################################################

%%MPV_OBJECT_ARGS_T%%

%%MPV_OBJECT_ARGS_PARAM_T%%

#######################################################################
# functions
#######################################################################

_mpv_cache_exists() {
  local key=$1 _key
  for _key in "${#_mpv_cache_t[@]}"; do
    if [[ $_key = $key ]]; then
      return 0
    fi
  done
  return 1
}

_mpv_cache_set() {
  local key=$1
  local data=$2
  _mpv_cache_t[$key]=$2
  return 0
}

_mpv_cache_get() {
  local key=$1
  if ! _mpv_cache_exists "$key"; then
    return 1
  fi
  printf "%s" "${_mpv_cache_t[$key]}"
  return 0
}

_mpv_drm_connectors(){
  type mpv &>/dev/null || return 0;
  mpv --no-config --drm-connector help \
  | awk '/\<connected\>/{ print $1 ; }'
}

_mpv_profiles(){
  type mpv &>/dev/null || return 0;
  mpv --profile help  \
  | awk '{if(NR>2 && $1 != ""){ print $1; }}'
}

_mpv_uniq(){
  local -A w
  local o=""
  for ww in "$@"; do
    if [[ -z "${w[$ww]}" ]]; then
      o="${o}${ww} "
      w[$ww]=x
    fi
  done
  printf "${o% }"
}

_mpv_xrandr(){
  local data
  if ! _mpv_cache_get xrandr ; then
    if [[ -n "$DISPLAY" ]]; then
      data=$(xrandr|while read l; do
        [[ $l =~ ([0-9]+x[0-9]+) ]] && echo "${BASH_REMATCH[1]}"
      done)
      _mpv_cache_set xrandr "$(_mpv_uniq "$data")"
    fi
  fi
  _mpv_cache_get xrandr || true
}

# Set the completion reply.
# _mpv_sh <reply word string> <current word>
_mpv_s(){
  local cmp=$1
  local cur=$2
  COMPREPLY=($(compgen -W "$cmp" -- "$cur"))
  return $?
}

# Given the name of a mpv option object <object> and a current word that
# represents a syntactically correct expression of adding options to said
# object, output a list of words that represents the possible completions of the
# current word.
#
# _mpv_objarg <object:str> <cur:str>
_mpv_objarg(){
  local object=$1
  local cur=$2 # --object=[...,]filter1:param1=
  shift 2

  local stripped_cur=${cur#=}
  local current_filter
  local current_filter_param
  local current_filter_param_value
  local key
  local response
  local slug

  #
  # case: --object=[filter:param=]...,filter:param=
  #
  if [[ $stripped_cur =~ : && $stripped_cur =~ =$ ]]; then
    current_filter=${stripped_cur##*,}
    current_filter=${current_filter%%:*}
    current_filter_param=${stripped_cur%=}
    current_filter_param=${current_filter_param##*:}
    key="${object}@${current_filter}@${current_filter_param}"
    if [[ ${_mpv_object_args_param_t[$key]+x} ]]; then
      for slug in ${_mpv_object_args_param_t[$key]}; do
        response="${response}${cur}${slug} "
      done
    fi
  #
  # case: --object=[filter:param=]...,filter:param=ab?
  #
  elif [[ ${stripped_cur##*,} =~ : && ${stripped_cur##*:} =~ = ]]; then
    current_filter=${stripped_cur##*,}
    current_filter=${current_filter%%:*}
    current_filter_param=${stripped_cur%=}
    current_filter_param=${current_filter_param##*:}
    key="${object}@${current_filter}@${current_filter_param}"
    current_filter_param_value=${stripped_cur##*=}
    if [[ ${_mpv_object_args_param_t[$key]+x} ]]; then
      for slug in ${_mpv_object_args_param_t[$key]}; do
        if [[ $slug =~ ^${current_filter_param_value} ]]; then
          response="${response}${cur%=*}=${slug} "
        fi
      done
    fi
  #
  # case: --object=[...,]filter:?
  #
  elif [[ $stripped_cur =~ :$ ]]; then
    current_filter=${stripped_cur##*,}
    current_filter=${current_filter%%:*}
    key="${object}@${current_filter}"
    for slug in ${_mpv_object_args_t[$key]}; do
      response="${response}${cur}${slug} "
    done
  #
  # case: --object=[...,]filter:ab?
  #
  elif [[ ${stripped_cur##*,} =~ : ]]; then
    current_filter=${stripped_cur##*,}
    current_filter=${current_filter:*}
    current_filter_param=${stripped_cur##*:} # is a fragment
    key="${object}@${current_filter}"
    for slug in ${_mpv_object_args_t[$key]}; do
      if [[ $slug =~ ^${current_filter_param} ]]; then
        response="${reponse}${cur%:*}:${slug} "
      fi
    done
  #
  # case: --object=filter,
  #
  elif [[ $stripped_cur =~ ,$ ]]; then
    for slug in "$@"; do
      response="${response}${cur}${slug} "
    done
  else
    #
    # case: --object=fil???
    #
    s=${p##*,}
    current_filter=${stripped_cur##*,}
    for slug in "$@"; do
      if [[ $slug =~ ^${current_filter} ]]; then
        response="${response}${cur%,*}${slug} "
      fi
    done
  fi
 printf "${response% }"
}

#######################################################################
# completion function
#######################################################################

%%MPV_COMPLETION_FUNCTION%%
