assume cs:boot_codes

boot_codes segment
boot_start:
    ;set stack
    mov ax,0
    mov bx,7c00h
    mov ss,ax
    mov sp,bx
    
    ;load main sys codes to 20D0:0000
    mov ax,20D0h
    mov es,ax
    mov bx,0
    
    mov al,2 ;sector number
    mov ch,0 ;magentic track index
    mov cl,2 ;sector index
    mov dh,0 ;magentic head index
    mov dl,0 ;driver index
    mov ah,2 ;read sector
    int 13h
    
    ;Jump to 20D0:0000
    mov ax,20D0h
    push ax
    mov ax,0
    push ax

    retf
boot_end:

boot_codes ends

;install boot segment to sector 1 and main codes to sector2
assume cs:install_codes
install_codes segment
install:
    ;install boot segment
    mov ax,boot_codes
    mov es,ax
    mov bx,offset boot_start
    mov cx,offset boot_end-offset boot_start
    mov cx,offset code_end-offset start

    mov al,1
    mov ch,0
    mov dh,0
    mov cl,1
    mov dl,0
    mov ah,3
    int 13h
    
    ;install main codes to sector 2
    mov ax,code
    mov es,ax
    mov bx, offset start
    
    mov al,2
    mov ch,0
    mov dh,0
    mov cl,2
    mov dl,0
    mov ah,3
    int 13h
    
    mov ax,4c00h
    int 21h

    
install_codes ends

assume cs:code
code segment
start:
    jmp entry

    menu1 db '1) reset pc',0
    menu2 db '2) start system',0
    menu3 db '3) clock',0
    menu4 db '4) set clock',0
    menu dw menu1,menu2,menu3,menu4

entry:
    ;set ds segment
    mov ax,cs
    mov ds,ax
    call cls

    ;jmp show_menu

    ;clean up keyborad buffers
clean_key_buffers:
    mov ah,1
    int 16h
    jz show_menu
    mov ah,0
    int 16h
    jmp clean_key_buffers

show_menu:
    mov cx,4
    mov bx,0
    mov dh,10
    mov dl,10

show_menu_s:
    push cx
    sub cx,cx
    mov cl,2
    mov si,menu[bx]
    call print
    add bx,2
    inc dh
    pop cx
    loop show_menu_s

wait_input:
    mov ah,0
    int 16h

    cmp al,'1'
    je reset

    cmp al,'2'
    je start_sys

    cmp al,'3'
    je clock

    cmp al,'4'
    je jmp_set_clock
    jmp wait_input

jmp_set_clock:
    jmp near ptr set_clock
reset:
    ;jmp ffff:0
    mov ax,0ffffh
    push ax
    mov ax,0
    push ax
    retf


;start the real os
start_sys:
    mov ax,0
    mov es,ax
    mov bx,7c00h

    mov al,1
    mov ch,0
    mov cl,1
    mov dh,0
    mov dl,80h
    mov ah,2
    int 13h

    mov ax,0
    push ax
    mov ax,7c00h
    push ax
    retf


    fmt db "**/**/** **:**:**",0
    ports db 9,8,7,4,2,0
    color db 2
    org_int9 dw 0,0
    is_ret db 0

clock:
    push ax
    push bx
    push cx
    push dx
    mov al,0
    mov is_ret,al
    
    ;install int9
    mov ax,0
    mov es,ax
    mov ax,word ptr es:[9*4]
    mov org_int9[0], ax
    mov ax, word ptr es:[9*4+2]
    mov org_int9[2], ax
    
    cli
    mov word ptr es:[9*4], offset int9
    mov word ptr es:[9*4+2], cs
    sti
    
    call cls

clock_start:    
    mov al,is_ret
    cmp al,1
    je clock_ret
    
    call get_clock
    
    ;diplay clock
    mov dh,12
    mov dl,30
    mov cl,color
    mov si,offset fmt
    call print
    
    jmp clock_start
    
clock_ret:
    mov ax,0
    mov es,ax
    mov ax,org_int9[0]
    mov bx,org_int9[2]
    cli
    mov word ptr es:[9*4], ax
    mov word ptr es:[9*4+2], bx
    sti
    pop dx
    pop cx
    pop bx
    pop ax
    jmp entry

get_clock:
    mov di,0
    mov bx,0
    mov cx,6

get_clock_s:
    mov al,ports[bx]
    out 70h,al
    in al,71h
    mov ah,al
    mov dx,cx
    mov cl,4
    shr ah,cl
    mov cx,dx
    and al,0fh
    add ah,30h
    add al,30h
    mov fmt[di],ah
    mov fmt[di+1],al
    add di,3
    inc bx
    loop get_clock_s
    ret
    
int9:
    push ax
    push bx
    push es
    
    in al,60h
    pushf 
    pushf
    pop bx
    and bh,11111100b
    push bx
    popf 
    call dword ptr org_int9
    
    cmp al,1 ;esc
    je retmain
    
    cmp al,3bh ;F1
    jne int9_ret
    mov al,color
    inc al
    mov color,al
    jmp int9_ret
    
retmain:
    mov al,1
    mov is_ret,al
    
int9_ret:
    pop es
    pop bx
    pop ax
    iret

    
;=====================================================  
set_clock:
    push ax
    push bx
    push cx
    push dx
    
    call cls
    call get_clock
    
    ;diplay clock
    mov dh,12
    mov dl,30
    mov cl,87h
    mov si,offset fmt
    call print
    
    mov ax,0b800h
    mov es,ax
    mov di,12*160+32*2
    
    mov cx,5
scs1:   
    mov byte ptr es:[di+1],7
    add di,6
    loop scs1
    
    mov bx,0 ;cursor
    
gather_key:     
    mov ah,2 ;set cursor
    mov bh,0 ;set page
    mov dh,12 ;line
    mov dl,30 ;column
    add dl,bl
    int 10h
    
    mov ah,0
    int 16h
    
    cmp ah,4bh
    je larrow
    cmp ah,4dh
    je rarrow
    cmp ah,1ch
    je write_clock

    cmp al,30h
    jb gather_key
    cmp al,39h
    ja gather_key

    mov di,bx
    add di,di
    add di,12*160+30*2
    mov es:[di],al
    mov fmt[bx],al
    jmp rarrow
    
rarrow:
    cmp bx,16
    je gather_key
    
    inc bx
    mov cx,5
    mov ax,2
ras:
    cmp bx,ax
    je fskip
    add ax,3
    loop ras
    jmp gather_key
fskip:
    inc bx
    jmp gather_key
    
larrow:
    test bx,bx
    je gather_key
    
    dec bx
    mov cx,5
    mov ax,2
las:
    cmp bx,ax
    je bskip
    add ax,3
    loop las
    jmp gather_key
bskip:
    dec bx
    jmp gather_key
    
write_clock:
    mov dh,13
    mov dl,30
    mov cl,2
    mov si,offset fmt
    call print

    mov di,15
    mov bx,0
    mov cx,6
set_clock_s:
    mov bx,cx
    mov dh,fmt[di]
    sub dh,30h
    mov dl,fmt[di+1]
    sub dl,30h
    mov cl,4
    shl dh,cl
    or  dl,dh
    mov cx,bx
    mov al,ports[bx-1]
    out 70h,al
    mov al,dl
    out 71h,al
    sub di,3
    loop set_clock_s
    mov ah,2
    mov bh,0
    mov dh,0
    mov dl,0
    int 10h

    jmp entry
    
;=========================================================
;clean up screen
cls:
    push ax
    push es
    push di
    push cx
    mov ax,0b800h
    mov es,ax
    mov di,0
    mov cx,1920
cls_s:
    mov byte ptr es:[di],32
    mov byte ptr es:[di+1],0
    add di,2
    loop cls_s
    
    pop cx
    pop di
    pop es
    pop ax
    ret 
    
print:
    push ax
    push bx
    push cx
    push di
    push si
    push es

    mov ax,0b800h
    mov es,ax

    ;compute the display memory address
    mov al,dh
    mov bl,160
    mul bl
    mov di,ax
    mov al,dl
    mov bl,2
    mul bl
    add ax,di
    mov di,ax

    ;set color and clean up ch
    mov ah,cl
    mov ch,0

s:  mov al,[si] ;copy a character
    mov cl,al
    mov es:[di],ax
    inc si
    inc di
    inc di
    inc cx
    loop s

    pop es
    pop si
    pop di
    pop cx
    pop bx
    pop ax
    ret

code_end:    

code ends
end install
;end start
