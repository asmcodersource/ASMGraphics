use16 
org 100h 
jmp start 
  
include "PROC16.INC"    ;; need for graph_lib
include "graph_lib.asm"

;;..............................._DrawDesc................................
;; This is a structure that stores values important for rendering. 
;; If you want add your custom properties to the rendering process, 
;; I recommend supplementing this structure.
;; To create an object of the GrfObr structure, you can use the following record:
;; 
;; objectname _DrawDesc video_addr_segmeng, video_addr_offset, shadow_buffer_segment, shadow_buffer_offset, render_width, render_height
;; You can see an example at the bottom of source code 


;;................................ functions .....................................  
;; initDisplayMode  - no args, initialize graphic mode and FPU           | Attention, FPU will loss current state  
;; clearDisplay     - pointer to _DrawDesc, color                        | Fill shadow render display
;; setPixel         - pointer to _DrawDesc, coord_x, coord_y, color      | Draw pixel
;; drawRectangle    - pointer to _DrawDesc, x1, y1, widht, height, color | Draw rectangle display on pos x1, y1
;; drawLine         - pointer to _DrawDesc, x1, y1, x2, y2               | Draw line display AB(x1,y1,x2,y2)
;; drawVerticalLine - pointer to _DrawDesc, x, y1, y2                    | Draw only vertical line display AB(x,y1,x,y2)
;; displayUpdate    - pointer to _DrawDesc                               | Output shadow display


;; I found the color palette here : https://www.fountainware.com/EXPL/vga_color_palettes.htm
    
start:      
    stdcall initDisplayMode                                   ;;  You do not have to use this function if you want to initialize yourself.
    mov ax, 0
    .infinity_cycle:
        stdcall clearDisplay, render_screen, ax                     ;;  Clears the (shadow)screen by filling it with the color from the last argument 
        stdcall drawRectangle, render_screen, 20, 20, 100, 100, 51h ;;
        stdcall drawLine, render_screen, 100,20,20,100,22h           ;;
        stdcall displayUpdate, render_screen                        ;;  output result from shadow screen to screen buffer
        inc al
        jmp .infinity_cycle                                                      
    

render_screen _DrawDesc 0A000h, 0000h, 08000h, 0000h, 320, 200  

