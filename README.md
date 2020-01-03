# fzf überzogen

fzf überzogen provides a shell script which allows to use [ueberzug](https://github.com/seebye/ueberzug) with fzf.  

## Overview

- [Installation](#pip-package)
- [Usage](#usage)
  * [Exported functions](#exported-functions)
    + [DRAW_PREVIEW](#draw_preview)
    + [CLEAR_PREVIEW](#clear_preview)
    + [ADD_PLACEMENT](#add_placement)
    + [REMOVE_PLACEMENT](#remove_placement)
- [Limitations](#limitations)
- [Examples](#examples)

## pip package

fzf-ueberzogen

## Usage

fzf-ueberzogen.sh is a wrapper script,
so it passes all received command line arguments to fzf.

### Exported functions

#### DRAW_PREVIEW

Name: DRAW_PREVIEW  
Description:  
Sends an add command to ueberzug which contains the passed path.  
The placement is specified by the x-, y-coordinate, width, height of the preview window of fzf.  
Centered cover is used as image scaler.  

Parameter:  

| Name          | Type         | Description                                                        | Optional |
|---------------|--------------|--------------------------------------------------------------------|----------|
| path          | String       | path to an image                                                   | No       |

#### CLEAR_PREVIEW

Name: CLEAR_PREVIEW  
Description:  
Sends a remove command to ueberzug with the identifier which is used by the DRAW_PREVIEW function.  

Parameter:  

| Name          | Type         | Description                                                        | Optional |
|---------------|--------------|--------------------------------------------------------------------|----------|
|               |              |                                                                    |          |

#### ADD_PLACEMENT

Name: ADD_PLACEMENT  
Description:  
Sends an add command to ueberzug with the passed data.  

Parameter:  

| Name          | Type                       | Description                                                        | Optional |
|---------------|----------------------------|--------------------------------------------------------------------|----------|
| add_command   | nameref[associative array] | An associative array which contains the data of an add command     | No       |
| adjust_rect   | nameref[function]          | A function(nameref[associative array] rect) which is called with the position and size of the preview window. It allows to change the placement position and size of an image. | Yes |

Example:  

```bash
# don't forget to 
# - export your functions
# - change the fzf preview command
function NEW_DRAW_PREVIEW {
    # Usage: DRAW_PREVIEW path
    local -A add_preview_command=( \
        [identifier]="my-identifier" \
        [scaler]=forced_cover [scaling_position_x]=0.5 [scaling_position_y]=0.5 \
        [path]="${@}")

    function adjust_rect {
        local -n placement_rect="$1"
        ((placement_rect[y]+=1))
        ((placement_rect[x]+=1))
        ((placement_rect[width]/=2))
        ((placement_rect[height]/=2))
    }
    ADD_PLACEMENT add_preview_command adjust_rect
}
```

#### REMOVE_PLACEMENT

Name: REMOVE_PLACEMENT  
Description:  
Sends a remove command to ueberzug with the passed identifier.  

Parameter:  

| Name          | Type         | Description                                                        | Optional |
|---------------|--------------|--------------------------------------------------------------------|----------|
| identifier    | String       | The identifier of the placement                                    | No       |


## Limitations

If fzf's height option (!=100%) is used  
**after a resize of the terminal window** it's not possible to figure out  
the correct position of fzf in the terminal window.  
Reason: Some terminal emulators change the visible content on resizing the window.  
So the initial y-offset of fzf isn't always the new y-offset of fzf.  
(Due to reasons how the communication in pseudo ttys works it's not possible to get the offset after the start of fzf.)  
So if the height option is used an the terminal gets resized a image will likely be placed at a unwanted position.  

## Examples

Examples can be found [here](https://github.com/seebye/fzf-ueberzogen/tree/master/examples).
