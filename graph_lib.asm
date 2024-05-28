;;..............................._DrawDesc................................
;; This is a structure that stores values important for rendering. 
;; If you want add your custom properties to the rendering process, 
;; I recommend supplementing this structure.
;; To create an object of the GrfObr structure, you can use the following record:
;; 
;; objectname _DrawDesc video_addr_segmeng, video_addr_offset, shadow_buffer_segment, shadow_buffer_offset, render_width, render_height
;; You can see an example below:
;; render_screen _DrawDesc 0A000h, 0000h, 08000h, 0000h, 320, 200  


;;................................ functions .....................................  
;; initDisplayMode  - no args, initialize graphic mode and FPU           | Attention, FPU will loss current state  
;; clearDisplay     - pointer to _DrawDesc, color                        | Fill shadow render display
;; setPixel         - pointer to _DrawDesc, coord_x, coord_y, color      | Draw pixel
;; drawRectangle    - pointer to _DrawDesc, x1, y1, widht, height, color | Draw rectangle display on pos x1, y1
;; drawLine         - pointer to _DrawDesc, x1, y1, x2, y2               | Draw line display AB(x1,y1,x2,y2)
;; drawVerticalLine - pointer to _DrawDesc, x, y1, y2                    | Draw only vertical line display AB(x,y1,x,y2)
;; displayUpdate    - pointer to _DrawDesc                               | Output shadow display


;; I found the color palette here : https://www.fountainware.com/EXPL/vga_color_palettes.htm



struc _DrawDesc display_offset_segment, display_offset, shadow_display_segment, shadow_display_offset, display_width, display_height 
     {
        .display_offset_segment dw display_offset_segment
        .display_offset         dw display_offset
        .shadow_display_segment dw shadow_display_segment
        .shadow_display_offset  dw shadow_display_offset
        .display_width          dw display_width
        .display_height         dw display_height
        .fpu_store              db 108 dup(?)
     }
     
proc initDisplayMode
    finit                   ;; FPU initialization
    mov ax, 0013h           ;; AH = 00h, AL = 13h 
    int 10h                 ;; call bios fuction 
    ;; if AH == 0, its function Set display mode, and AL must store mode number, here its 13h - 320x200, 256 colors palette
    ;; more info: 
    ;; int 10h                - https://en.wikipedia.org/wiki/INT_10H
    ;; video moder for func 0 - http://www.columbia.edu/~em36/wpdos/videomodes.txt 
    ret
endp
     
proc clearDisplay draw_desc, color
    pusha                   ;; stores all registers to the stack
    mov bx, [draw_desc]     ;; get pointer of _DrawDesc struct object
    mov es, [bx + 4]        ;; get shadow display segment -> ES
    mov di, [bx + 6]        ;; get shadow display offset  -> DI
    
    ;; get end value for cylce
    mov si, di              ;; mov si, start addr          | si now contain start_addr   
    mov ax, [bx + 8]        ;; get width -> ax             | ax now contain widht
    mov dx, [bx + 10]       ;; get height -> dx            | dx now contain height
    mul dx                  ;; multiple ax * dx            | (ax)size = (ax)widht * (dx)height
    add si,ax               ;; add result to start address | (si)end_addr = (si)start_addr + (ax)size

    mov al, byte [color]       ;; set color to al, and ah  \ for use 16bit instruction stos 
    mov ah, al  
    
    .cycle:                     ;; .cycle is the same as writing clearDisplay.cycle 
        stosw                   ;; mov [es:di], ax | AND add di, 2
        cmp di, si              ;; compare di, and si
        jne .cycle              ;; if di not eques to si, jump to point .cycle   
        
    popa                  ;; restores all registers from the stack
    ret
endp

proc displayUpdate draw_desc
    pusha                   ;; stores all registers to the stack
    mov bx, [draw_desc]     ;; get pointer of _DrawDesc struct object
    mov es, [bx + 0]        ;; get display segment -> ES
    mov di, [bx + 2]        ;; get display offset  -> ES
                            
    ;; Here get end value for cylce: 
    mov cx, di              ;; mov cx, start addr          | cx now contain start_addr   
    mov ax, [bx + 8]        ;; get width -> ax             | ax now contain width
    mov dx, [bx + 10]       ;; get height -> dx            | dx now contain height
    mul dx                  ;; multiple ax * dx            | (ax)size = (ax)widht * (dx)height
    add cx,ax               ;; add result to start address | (cx)end_addr = (cx)start_addr + (ax)size 
               
    mov si, [bx + 6]        ;; start offset of shadow display -> SI  
    
    push ds                 ;; save DS state
    mov ax, [bx + 4]        ;; We did it cause we cant do mov ds,[bx + 4] ( showdow display segmeng )  
    mov ds, ax              ;; shadow display segment <- AX !!! Attention, We change DS register, now variable access is not possible  !!!
    
    .cycle:                     ;; .cycle is the same as writing displayUpdate.cycle
        lodsw                   ;; is the same as -> mov ax, [ds:si] | AND add si, 2 \ This lines works
        stosw                   ;; is the same as -> mov [es:di], ax | AND add di, 2 \ like memcpy( (es:di)addr_destination, (ds:si)addr_soruce, (cx)size ) C\C++ 
        cmp di, cx              ;; compare di, and cx
        jne .cycle              ;; ;; if di not eques to cx, jumpt to point .cycle
     
    pop ds                  ;; save DS state
    popa                    ;; restores all registers from the stack, DS restored here
    ret
endp

proc setPixel draw_desc, coord_x, coord_y, color
    pusha                   ;; stores all registers to the stack
    mov bx, [draw_desc]     ;; get pointer of _DrawDesc struct object
    mov es, [bx + 4]        ;; get shadow display segment -> ES
    mov di, [bx + 6]        ;; get shadow display offset  -> DI
    
    ;; coordinate validity check
    mov ax, [coord_x]       ;; ax now contain coord_x
    cmp ax, [bx + 8]        ;; compare (ax)coord_x and ([bx+8])width 
    jae .exit               ;; if (ax)coord_x >= ([bx+8])width -> jump to .exit
    mov ax, [coord_y]       ;; ax now contain coor_y
    cmp ax, [bx + 10]       ;; compare (ax)coord_y and ([bx+10])height
    jae .exit               ;; if (ax)coord_y >= ([bx+10])height -> jump to .exit
    
    ;; get pixel coordinate on shadow display
    mov si, di              ;; mov si, start addr          | si now contain start_addr   
    mov ax, [bx + 8]        ;; get width -> ax             | ax now contain widht
    mov dx, [coord_y]       ;; get y -> dx                 | dx now contain coord_y
    mul dx                  ;; multiple ax * dx            | (ax)linear_addr_y = (ax)widht * (dx)coord_y
    add si,ax               ;; add result to start address | (si)pixel_addr = (si)start_addr + (ax)linear_addr_y + coord_x  
    add si, [coord_x]       ;; \ *look upper*
    
    ;; set pixel on shadow display
    mov di,si               ;; cause stosb works like mov [es:di], al
    mov al,byte [color]     ;; get color to AL, cause look upper 
    stosb                   ;; set pixel on shadow display | (es)shadow_display_segment:(di)pixel_addr = (ax)color | *(es:di)addr = (ax)color
    
        .exit:              ;; .exit is the same as writing  setPixel.exit
        popa                ;; restores all registers from the stack
        ret
endp


proc drawRectangle draw_desc, coord_x, coord_y, width, height, color
    pusha                   ;; stores all registers to the stack 
    
    ;; It doesn't make much sense to comment, I'd rather leave the analogue of the code in C\C++ 
    mov di, [coord_y]                                      ;;     di = coord_y;
    mov cx, [height]                                       ;;     cx = height; 
    add cx, di                                             ;;     cx = cx + height;
    .cycle_drawing:                                        ;;     while( di != cx ){ 
        mov si, [coord_x]                                  ;;         si = coord_x;
        mov bx, [width]                                    ;;         bx = width
        add bx, si                                         ;;         end_value_x = si + bx;   it would be better to take it out for the body of the loop, but I have already written comments.
        .cycle_draw_horizontal:                            ;;         while( si != bx ){
            stdcall setPixel, [draw_desc], si, di, [color] ;;             setPixel(draw_desc, si, di, color);
            inc si                                         ;;             si++;
            cmp si, bx                                     ;;             
            jne .cycle_draw_horizontal                     ;;         }
        inc di                                             ;;         di++
        cmp di, cx                                         ;;
        jne .cycle_drawing                                 ;;     }
              
    popa                    ;; restores all registers from the stack
    ret
endp 


proc drawVerticalLine draw_desc, x, y1, y2, color   
    pusha                        ;; stores all registers to the stack
    mov ax, [y1]                 ;; ax now contain y1
    mov bx, [y2]                 ;; bx now contain y2
    cmp ax,bx                    ;; compare (ax)y1 and (bx)y2
    ja .skip_swap                ;; if (ax)y1 > (bx)y2 jump to ..skip_swap  
        xchg ax, bx                 ;; this instruction swap registers
    .skip_swap:                  ;;         
    sub ax, bx                   ;; (ax)delta_y = (ax)y2 - (bx)y1   
    mov di, bx                   ;; set start DI to Y1, we drawing line to down, by adding 1.
    .cycle_draw_vertical_line:   
        stdcall setPixel, [draw_desc], [x], di, [color] ;; draw pixel at point([X1],di) with color [color] on display context [draw_desc]
        cmp ax, 0000h                                    ;; compare si and nunber 0000h
        jz .exit                                         ;; if si == 0000, jump to .exit
        dec ax                                           ;; si = si - 1
        inc di                                           ;; di = di + 1
        jmp .cycle_draw_vertical_line                    ;; and jump to .cycle_draw_vertical_line  
    .exit:
    popa                    ;; restores all registers from the stack
    ret
endp 
       

proc drawLine draw_desc, x1, y1, x2, y2, color
    pusha                  ;; stores all registers to the stack
    add sp, -6             ;; move stack pointer down to alloc local variables
    mov bx, [draw_desc]    ;; get pointer to DrawDesc struct
    fsave [bx + 12]        ;; store FPU state to draw_desc.fpu_store
    
    ;; if x1 > x2, swap points
    mov ax, [x1]           ;; ax is x1
    cmp ax, [x2]           ;; compare (ax)x1 and x2
    jbe .skip_swap         ;; if x1 < x2, jump to .skip_swap, else:
        push ax                 ;; using stack to swap values X1 <-> X2 AND Y1 <-> Y2
        push [x2]               ;; How its works:
        pop [x1]                ;;      push 1 -> shift stored values, and store 1 -> stack state: (1)
        pop [x2]                ;;      push 2 -> shift stored values, and store 2 -> stack state: (2, 1)
        push [y1]               ;;      
        push [y2]               ;;      pop get fisrt value from stack, and delete them
        pop [y1]                ;;      pop var1 -> get value 2 to var1 -> delete this value from stack -> stack state: (1)
        pop [y2]                ;;      pop var2 -> get value 1 to var2 -> delete this value from stack -> stack state: (<nothing>) 
         
    .skip_swap:            ;; here exactly  X1 < X2 
    mov ax, [x2]           ;; get X2 -> AX
    sub ax, [x1]           ;; (ax)delta_x = (ax)x2 - x1 
    cmp ax, 0000h          ;; compare (ax)delta_x and zero
    jnz .draw_normal_line  ;; if (ax)delta_x == 0, jump to point. draw_normal_line
        stdcall drawVerticalLine, [draw_desc], [x1], [y1], [y2], [color]
        jmp .exit
    .draw_normal_line:
    mov [bp-18], ax ;; -18 ;; store (ax)delta_x value to stack, we know first stack value pos is bp - 2, but pusha add -16 to sp
    mov ax, [y2]           ;; get Y2 -> AX
    sub ax, [y1]           ;; (ax)delta_y = (ax)y2 - y1
    mov [bp-20], ax ;; -20 ;; store (ax)delta_x value to stack, we know second stack value pos is bp - 4, but pusha add -16 to sp 
    fild word [bp-20]      ;; load ([bp - 20])delta_y to FPU, now ST0 its delta_y
    fidiv word [bp-18]     ;; (ST0)y_step = (ST0)delta_y / ([bp-18]) delta_x
    mov ax, [x1]           ;; set start values for cycle
    fild [y1]              ;; load y1 ( let's name it current_y ) to FPU, now current_y is ST0, y_step was shifted, and now it's stored in ST1     
    
    ;; line drawing cycle
    .cycle_draw_line:    
        mov bx, [y1]                                      ;; get current_y to bx 
        mov [bp-22], bx                                   ;; store current_y  to stack
        stdcall setPixel, [draw_desc], ax, bx, [color]    ;; draw pixel at point(AX,BX) with color [color] on display context [draw_desc]
        fadd st0,st1                                      ;; (ST0)current_y = (ST0)current_y + (ST1)y_step 
        fist [y1]                                         ;; load (ST0)current_y to [y1] 
        
        mov bx, [bp-22]                                   ;; get current_y -> BX
        sub bx, [y1]                                      ;; (bx)temp_delta_y = (bx)temp_delta_y - ([y1])current_y
        inc bx                                            ;; add 1 for shift posible good values from [-1,1], to [0,2]
        cmp bx, 02                                        ;; compare bx and 02 | if the difference is less than 1 (0 <= BX <= 2 ), then there are no gaps
        jbe .no_gaps_on_line
            stdcall drawVerticalLine, [draw_desc], ax, word [bp-22], word [y1], [color]     
        .no_gaps_on_line:
        inc ax                                            ;; (ax)X = (ax)X + 1
        cmp ax, [x2]                                      ;; compare X, and X2
        jb .cycle_draw_line                              ;; if X != X2, jump to .cycle_draw_line  
            
    .exit:
    mov bx, [draw_desc]    ;; restore FPU state from draw_desc.fpu_store
    frstor [bx + 12]       ;; look upper
    add sp, 6              ;; Return SP to original position, look start of func
    popa                   ;; restores all registers from the stack
    ret
endp  


proc drawCircle draw_desc, x1, y1, radius_width, radius_height, color
    pusha
    add sp, -6             ;; move stack pointer down to alloc local variables
    mov bx, [draw_desc]    ;; get pointer to DrawDesc struct
    fsave [bx + 12]        ;; store FPU state to draw_desc.fpu_store   
    
    popa
    ret
endp