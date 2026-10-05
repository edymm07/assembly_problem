section .note.GNU-stack

section .bss
	;variabile globale pentru backtracking
	;buffer pentru secventa(max 2*n elemente ,aloc dinamic)
	work_buffer: resq 1
	;n curent
	curent_n: resd 1
	;2*n(lungimea totala a secventei)
	curent_len: resd 1
	;array de pointeri la secvente generate
	arr: resq 1
	;numarul curent de secvente generate
	nr_sec: resd 1
	;capacitatea array ului de rezultate
	cap: resd 1

section .text

extern malloc
extern free
extern realloc
extern memset

global check_langford
global generate_langford_sequences
;int check_langford(int *sequence , int len)
;rdi = sequence , esi = len
check_langford:
	push rbp
	mov rbp, rsp
	push rbx
	push r12
	push r13
	push r14
	push r15

	mov r12 , rdi ;r12 = sequence
	mov r13d , esi ;r13d = len

	; len trebuie sa fie par si > 0
	test r13d , r13d
	jz .nu_e
	mov eax , r13d
	; 1 = bitul cel mai putin semnificativ; testez paritatea
	and eax , 1
	jnz .nu_e

	; n = len / 2
	mov r14d , r13d
	; shift right cu 1 = impartire la 2
	shr r14d , 1

	; aloc un array de marker-uri (n+1 int-uri) ca sa numar cate aparitii are fiecare k
	mov eax , r14d
	inc eax
	; *4 = (n+1) * sizeof(int)
	shl eax , 2
	movsxd rdi , eax
	push rdi
	; aliniere stack la 16 bytes (push rdi face stack-ul nealiniat)
	sub rsp , 8
	call malloc wrt ..plt
	; refac stack-ul (cei 8 bytes de aliniere)
	add rsp , 8
	pop rdi
	mov r15 , rax ;r15 = array de count-uri

	; initializez cu 0 prin memset
	mov rdi , r15
	xor esi , esi
	mov eax , r14d
	inc eax
	; *4 = (n+1) * sizeof(int) pentru memset
	shl eax , 2
	movsxd rdx , eax
	call memset wrt ..plt

	; parcurg secventa si verific fiecare element
	; pentru fiecare valoare k, verific:
	; 1. 1 <= k <= n
	; 2. count[k] < 2 (nu apare mai mult de 2 ori)
	; 3. daca e a 2-a aparitie, distanta intre indici trebuie sa fie k+1
	; Folosesc count[k] pentru a sti daca am vazut k inainte si la ce index
	; Strategie: in count[k] tin (index_prima_aparitie + 1) sau 0 daca n-am vazut

	xor ebx , ebx ;i = 0
.loop:
	cmp ebx , r13d
	jge .verifica_final
	; k = sequence[i]
	movsxd rax , ebx
	; *4 = i * sizeof(int)
	mov ecx , [r12 + rax*4]
	; verific 1 <= k <= n
	test ecx , ecx
	jle .nu_e_dealoc
	cmp ecx , r14d
	jg .nu_e_dealoc
	; iau count[k]
	movsxd rax , ecx
	; *4 = k * sizeof(int)
	mov edx , [r15 + rax*4]
	test edx , edx
	jnz .a_doua_aparitie
	; prima aparitie: salvez (i+1) in count[k]
	mov edx , ebx
	inc edx
	; *4 = k * sizeof(int)
	mov [r15 + rax*4] , edx
	jmp .next

.a_doua_aparitie:
	; count[k] contine (index_prim + 1), deci index_prim = count[k] - 1
	dec edx
	; distanta = i - index_prim
	mov esi , ebx
	sub esi , edx
	; trebuie sa fie k+1
	mov edi , ecx
	inc edi
	cmp esi , edi
	jne .nu_e_dealoc
	; marchez ca am terminat acest k (pun valoare speciala -1 ca sa nu mai fie folosit)
	; 0 = valoarea care indica "neutilizat", -1 = "deja inchis de doua ori"
	mov dword [r15 + rax*4] , -1

.next:
	inc ebx
	jmp .loop

.verifica_final:
	; toate valorile k=1..n trebuie sa fi fost folosite de 2 ori (count[k] = -1)
	mov ecx , 1
.verif_loop:
	cmp ecx , r14d
	jg .e_valid
	movsxd rax , ecx
	; *4 = k * sizeof(int)
	mov edx , [r15 + rax*4]
	; -1 = marcaj pentru k folosit corect de doua ori
	cmp edx , -1
	jne .nu_e_dealoc
	inc ecx
	jmp .verif_loop

.e_valid:
	mov rdi , r15
	call free wrt ..plt
	; 1 = secventa este Langford
	mov eax , 1
	jmp .gata_check

.nu_e_dealoc:
	mov rdi , r15
	call free wrt ..plt
.nu_e:
	; 0 = secventa nu este Langford
	xor eax , eax

.gata_check:
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	leave
	ret
	; TODO - write the check_langford function
;int **generate_langford_sequences(int n , int *seq_num)
;rdi  = n , rsi = seq_num
generate_langford_sequences:
	push rbp
	mov rbp, rsp
	push rbx
	push r12
	push r13
	push r14
	push r15
	;8 bytes pentru seq_num
	sub rsp , 16

	;salvez seq_num
	mov [rsp] , rsi

	mov r12d , edi ;r12d=n
	;setez variabilele globale
	mov [rel curent_n] , edi
	add edi , edi ; *2 = 2*n
	mov [rel curent_len] , edi
	;results initial: capacitate 16
	;16 * 8 = 128 bytes
	mov rdi , 128
	call malloc wrt ..plt
	mov [rel arr] , rax
	;16 = capacitatea initiala a array ului de rezultate
	mov dword [rel cap] , 16
	;0 = numarul initial de secvente generate
	mov dword [rel nr_sec] , 0

	;aloc bufferul de lucru(2*n int uri = 8*n bytes)
	mov eax , [rel curent_len]
	;*4 = 2n*sizeof(int)
	shl eax , 2
	movsxd rdi , eax
	call malloc wrt ..plt
	mov [rel work_buffer] , rax
	;initializez cu 0 (toate pozitiile libere)
	mov rdi , rax
	xor esi , esi
	mov eax , [rel curent_len]
	;*4 = 2n*sizeof(int) pentru memset
	shl eax , 2
	movsxd rdx , eax
	call memset wrt ..plt
	;daca n = 0 nu generam nimic
	mov eax , [rel curent_n]
	test eax , eax
	jz .gata_gen
	;verifica rapida: secvente Langford exista doar pt n % 4 in {0 , 3}

	;apelez backtracking pentru a plasa pozitia 0
	xor edi , edi ; index = 0
	call bt

.gata_gen:
	;eliberez bufferul de lucru
	mov rdi , [rel work_buffer]
	call free wrt ..plt

	;setez *seq_num
	mov rcx , [rsp]
	mov eax , [rel nr_sec]
	mov [rcx] , eax
	;daca nu am gasit nicio secventa , eliberez array-ul si returnez NULL
	test eax , eax
	jnz .returnez_arr
	mov rdi , [rel arr]
	call free wrt ..plt
	xor eax , eax
	jmp .gata_generate

.returnez_arr:
	mov rax , [rel arr]

.gata_generate:
	;refac stack-ul(16 bytes = 8 salvare seq_num + 8 aliniere)
	add rsp , 16
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	leave 
	ret

;void bt(int index)
;edi = pozitia curenta unde incercam sa plasam ceva
;backtracking: pentru pozitia index, incerc valorile k de la 1 la n
;daca k nu a fost plasat inca si pozitia index+k+1 e libera
bt:
	push rbp
	mov rbp , rsp
	push rbx
	push r12
	push r13
	push r14
	;aliniere stack la 16 bytes
	sub rsp , 8

	mov r12d , edi ;r12d = index curent

	;daca am ajuns la sfarsit , am o secventa completa
	mov eax , [rel curent_len]
	cmp r12d , eax
	jge .salveaza

	;daca pozitia curenta e ocupata , sar peste ea
	mov rbx , [rel work_buffer]
	movsxd rax , r12d
	;*4 = index * sizeof(int)
	mov ecx , [rbx + rax*4]
	test ecx , ecx
	jz .incearca_valori
	;pozitia ocupata si fac recursivitatea cu index+1
	mov edi , r12d
	inc edi
	call bt
	jmp .gata_bt

.incearca_valori:
	;incerc k = 1,2,3,...,n
	mov r13d , 1

.loop_k:
	mov eax , [rel curent_n]
	cmp r13d , eax
	jg .gata_bt

	;verific daca k a fost deja folosit (caut in buffer)
	;mai eficient ar fi un v[] dar asa verific direct
	;daca exista work_buffer[i] == k pentru i <index , k e folosit
	;SAU:dupa cum le plasez(sortat lexicografic , mereu de la stanga la dreapta)
	;daca incerc valoarea k ,ar trebui sa nu fi fost plasata
	;pentru asta tin un v[] ca array global

	;parcurg de la 0 la iindex-1 sa caut un k
	xor r14d , r14d ;j = 0

.cauta_loop:
	cmp r14d , r12d
	jge .nu_e_folosit
	movsxd rax , r14d
	;* 4 = j*sizeof(int)
	mov ecx , [rbx + rax*4]
	cmp ecx , r13d
	je .urmatorul_k
	inc r14d
	jmp .cauta_loop

.nu_e_folosit:
	;pozitia index+k+1 trebuie sa fie in interval si libera
	mov eax , r12d
	add eax , r13d
	; +1 = distanta intre cele 2 aparitii ale lui k este k+1
	inc eax
	mov edx , [rel curent_len]
	cmp eax , edx
	jge .urmatorul_k
	;verific ca e libera
	movsxd rdx , eax
	;* 4 =(index+k+1) * sizeof(int)
	mov ecx , [rbx + rdx*4]
	test ecx , ecx
	jnz .urmatorul_k

	;plasez k pe pozitiile r12 si r12+k+1
	movsxd rdx , r12d
	;*4 = index*sizeof(int)
	mov [rbx + rdx*4] , r13d
	movsxd rdx , eax
	; *4 = (index+k+1) * sizeof(int)
	mov [rbx + rdx*4] , r13d

	; recursivitate cu index+1
	mov edi , r12d
	inc edi
	call bt

	mov rbx , [rel work_buffer]
	;sterge de pe ambele pozitii
	movsxd rdx , r12d
	;0 = pozitie libera
	mov dword [rbx + rdx*4] , 0
	;recalculez index+k+1 pt a doua pozitie
	mov eax , r12d
	add eax , r13d
	inc eax 
	movsxd rdx , eax
	;0=pozitie libera(a doua pozitie)
	mov dword [rbx + rdx*4] , 0


.urmatorul_k:
	inc r13d 
	jmp .loop_k

.salveaza:
	;am o secventa completa,o copiez intr un buffer nou si o adaug la results
	mov eax , [rel curent_len]
	;*4 = 2n*sizeof(int) pentru malloc
	shl eax , 2
	movsxd rdi , eax
	call malloc wrt ..plt
	mov r14 , rax ;r14=noul buffer

	;copiez work_buffer in noul buffer
	mov rbx , [rel work_buffer]
	xor r13d , r13d

.copy_loop:
	mov eax , [rel curent_len]
	cmp r13d , eax
	jge .gata_copy
	movsxd rax , r13d
	;*4 = j* sizeof(int)
	mov ecx , [rbx + rax*4]
	;*4 = i * sizeof(int) - citesc din work_buffer
	mov [r14 + rax*4] , ecx
	inc r13d
	jmp .copy_loop

.gata_copy:
	;verific daca trebuie sa maresc arr
	mov eax , [rel nr_sec]
	mov ecx , [rel cap]
	cmp eax , ecx
	jl .adauga_direct
	;dublez capacitatea
	add ecx , ecx
	mov [rel cap] , ecx
	mov rdi , [rel arr]
	movsxd rsi , ecx
	;*8 = new_cap * sizeof(pointer)
	shl rsi , 3
	push r14
	;aliniere stack la 16 bytes
	sub rsp , 8
	call realloc wrt ..plt
	;refac stack ul(cei 8 bytes de aliniere)
	add rsp , 8
	pop r14
	mov [rel arr] , rax
	mov eax , [rel nr_sec]

.adauga_direct:
	mov rdi , [rel arr]
	movsxd rcx , eax
	;*8 = index *sizeof(pointer)
	mov [rdi + rcx * 8] , r14
	inc eax
	mov [rel nr_sec] , eax

.gata_bt:
	;refac stack ul 
	add rsp , 8
	pop r14
	pop r13
	pop r12
	pop rbx
	leave
	ret	; TODO - write the generate_langford_sequences function
