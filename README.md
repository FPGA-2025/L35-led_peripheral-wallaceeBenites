# Adicionando Periférico de LED ao Processador

Esta atividade irá adicionar um periférico de LEDs ao processador como exemplo de criação de um System on Chip (SoC). Etapas como a organização do espaço de endereços e a criação do barramento de periféricos também serão abordadas. Ao final da atividade, terá sido desenvolvido um microcontrolador básico com um periférico.

## Utilizando periféricos

Um processador sozinho é capaz de fazer muitas coisas: realizar cálculos complexos, tomar decisões de fluxo de execução baseadas nos dados, entre outras coisas. Apesar desse conjunto de capacidades, ele ainda não tem meios de interagir com o mundo externo, algo fundamental para a criação de uma aplicação prática.

É justamente nesse ponto que entram os periféricos, módulos capazes de interagir com o mundo externo a partir de comandos provenientes do processador. Existe uma enorme diversidade de periféricos possíveis:

- General Purpose I/O (GPIO) para gerar sinais elétricos externos
- módulos de comunicação como I2C
- geradores de sinal como HDMI
- contadores de tempo (timers) para aplicações de tempo real

Todos esses periféricos aparecem na forma de módulos escritos em HDL que comunicam com o processador por meio de um barramento.

## Periféricos mapeados em memória e barramento de comunicação

O processador pode se comunicar com os periféricos com a criação de instruções especiais (o caminho de dados é adaptado para receber o periférico) ou então o uso de mapeamento em memória (leituras e escritas em regiões específicas da memória controlam os periféricos). Nesta atividade iremos utilizar o princípio do mapeamento em memória.

Um periférico mapeado em memória divide um espaço de memória com o processador, de forma que eles podem se comunicar lendo e escrevendo nesse espaço. Os bytes lidos e escritos podem ser tanto comandos para o periférico quanto dados a serem utilizados.

![mapa_de_memoria](img/embarcatech-memory-mapped.svg)

Do ponto de vista do processador, ele está simplesmente realizando uma operação de memória. Do ponto de vista de sistema, o processador está escrevendo na interface do periférico. Para que a comunicação entre processador e periférico ocorra, é necessáro ligar os sinais do barramento de memória no periférico. Além de fazer essa ligação, também é necessário criar uma lógica de controle que separe os acessos da memória e do periférico. Sem essa separação, pode haver um conflito no qual a memória e o periférico tentam acessar o barramento ao mesmo tempo.

![barramento_de_memoria](img/embarcatech-barramento.svg)

## Periférico de LEDs

O periférico de LEDs nada mais é que um periférico capaz de receber dados do processador e expor esses dados nos pinos do FPGA. Esses pinos serão utilizados para acender os LEDs da placa de testes.

O módulo de LEDs deve ter uma porta de escrita que armazena os dados a serem mostrados num registrador de 8 bits. Além disso, deve haver uma porta de leitura para que o valor que aparece nesse registrador possa ser lido. Cada porta está associada a um endereço diferente do periférico.

| Endereço | Função                         |
|----------|--------------------------------|
| 0x00     | Escrita no registrador dos LEDs|
| 0x04     | Leitura do estado dos LEDs     |

Isso significa que o endereço 0 é de apenas escrita e o endereço 4 é de apenas leitura. Para cumprir com esse comportamento, a interface do periférico deve ser a seguinte:

```verilog
module led_peripheral(
    input  wire clk,
    input  wire rst_n,
    //ligação com o processador
    input wire rd_en_i,
    input wire wr_en_i,
    input wire [31:0] addr_i,
    input  wire [31:0] data_i,
    output wire [31:0] data_o,
    // ligação com o mundo externo
    output wire [7:0] leds_o
);
```

Outra observação importante é que, como o periférico possui apenas dois endereços possíveis, ele não precisa verificar todos os bits do barramento de endereço. Você pode, dentro do módulo, truncar o endereço (como no trecho de código abaixo). Na próxima seção será mostrado porque isso é permitido.

```verilog
assign effective_address = addr_i[3:0];
```

>Dica: no periférico de lEDs, apenas os 8 bits menos significativos dos dados são usados. Os demais devem ser ignorados.

## Ligação do Barramento

Para impedir conflitos entre o periférico e a memória, deve ser criada uma lógica capaz de separar os sinais dos dois. Essa lógica é responsável por ler o endereço que o processador deseja acessar e decidir se aquele endereço corresponde à memória ou ao periférico mapeado.

A separação dos sinais é feita por meio de multiplexadores, que propagam os sinais (`wr_en_i`, `rd_en_i`, `addr_i`, `data_i` e `data_o`) para o módulo correspondente apenas se o seu endereço estiver sendo acessado. No caso do nosso periférico, faremos o seguinte mapa de memória:

| Endereço                | Dispositivo                    |
|-------------------------|--------------------------------|
| 0x00000000 - 0x7FFFFFFF | Memória de programa e de dados |
| 0x80000000 - 0x8000000F | LEDs                           |
| 0x80000010 - 0xFFFFFFFF | Reservado                      |

As imagens abaixo ilustram as ligações do barramento para os diferentes endereços.

![barramento_periferico](img/embarcatech-barramento-periferico.svg)
![barramento_memoria](img/embarcatech-barramento-memoria.svg)

>Dica: para tirar um módulo do barramento basta colocar todos os seus sinais em zero.

Essa lógica de ligações significa que, quando o periférico é acessado, apenas uma faixa de endereços é permitida. No caso dos LEDs, o endreço vai estar sempre no formato `0x8000000D`, onde D é o único digito que pode variar. Por isso, o periférico pode ignorar a maior parte do endereço recebido.

A interface proposta para o interconexão de barramento é a seguinte:

```verilog
module bus_interconnect (
    // sinais vindos do processador
    input   wire proc_rd_en_i,
    input   wire proc_wr_en_i,
    output  wire [31:0] proc_data_o,
    input   wire [31:0] proc_addr_i,
    input   wire [31:0] proc_data_i,

    //sinais que vão para a memória
    output   wire mem_rd_en_o,
    output   wire mem_wr_en_o,
    input    wire [31:0] mem_data_i,
    output   wire [31:0] mem_addr_o,
    output   wire [31:0] mem_data_o,

    //sinais que vão para o periférico
    output   wire periph_rd_en_o,
    output   wire periph_wr_en_o,
    input    wire [31:0] periph_data_i,
    output   wire [31:0] periph_addr_o,
    output   wire [31:0] periph_data_o
);

```

## Programando o microcontrolador

Para poder utilizar o periférico, é necessário programar o microcontrolador. Siga os passos do laboratório anterior para gerar o arquivo `programa.txt` com as instruções. Use o [RISC-V Online Assembler](https://riscvasm.lucasteske.dev/) e pegue as instruções do campo `Code Hex Dump`.

O código em assembly a ser escrito deve ter a seguinte estrutura:

```assembly
.globl _boot
.section .text

_boot:
    # Neste trecho deve ser carregado o endereço do periférico e o valor a ser colocado nos LEDs
    # Para carregar os valores, use as intruções 'addi' e 'lui'
    # Para enviar os dados ao periférico, use a instrução 'sw'
    # Para ler do periférico, use a instrução 'lw'

loop:
    j loop                # Loop infinito para encerrar o programa
```

>IMPORTANTE: não use pseudoinstruções (como por exemplo `li`) em seu código. Se usar, o montador irá gerar instruções incompatíveis com o nosso processador.

## Atividade

Desenvolva os módulos do controlador de LEDs e da interconexão de barramentos. Esses módulos farão parte do novo `top module` do nosso projeto, que agora pode ser considerado um microcontrolador básico. A interface do topo deve ser modificada para permitir a conexão com os LEDs. A estrutura do projeto e a interface são mostrados a seguir.

```text
ESTRUTURA DO PROJETO:

core_top.v (SoC)
|_ bus_interconnect.v
|_ led_peripheral.v
|_ memory.v
|_ core.v
    |_ ALU, Reg File, etc 
```

```verilog
module core_top #(
    parameter MEMORY_FILE = "programa.txt"
)(
    input  wire        clk,
    input  wire        rst_n,
    
    output wire [7:0] leds
);
```
Você também deve criar o código assembly para que o microcontrolador "acenda" os LEDs correspondentes.

## Execução da Atividade

Reúna os arquivos do processador das atividades anteriores e adicione os novos componentes com os templates fornecidos. Execute os testes com o script `./run-all.sh`. O resultado será exibido como `OK` em caso de sucesso ou `ERRO` se houver alguma falha.

Se necessário, crie casos de teste adicionais para validar sua implementação.

>IMPORTANTE: assim como nas atividades anteriores, a memória deve ser instanciada como `mem` e o array de memória deve se chamar `memory`

## Entrega

Realize o *commit* no repositório do **GitHub Classroom**. O sistema de correção automática irá executar os testes e atribuir uma nota com base nos resultados.

> **Dica:**
> Não modifique os arquivos de correção. Para entender melhor o funcionamento dos testes, consulte o script `run.sh` disponível no repositório.