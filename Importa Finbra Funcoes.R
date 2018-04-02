# Script para Importar dados do Finbra no R.

# Script Para guardar as fun��es de extra��o dos dados do Finbra.

# Criado por Murilo Junqueira.

# Data cria��o: 2018-02-27.
# Ultima modifica��o: 2018-03-01.


################## Carrega pacotes necess�rios ##################

# Lista de pacotes necess�rios para as fun��es desse arquivo.
list.of.packages <- c("tidyverse",
                      "data.table", 
                      "dplyr", 
                      "tidyr", 
                      "stringr",
                      "lubridate",
                      "readxl")

# Verifica os que n�o est�o instalados
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]

# Instala os pacotes n�o instalados
if(length(new.packages)) install.packages(new.packages)

# L� todos os pacotes
for(i in 1:length(list.of.packages)) {
  #print(paste("Lendo o pacote", list.of.packages[i]))
  library(list.of.packages[i], character.only = TRUE)  
}

# Libera mem�ria
rm(list.of.packages, new.packages, i)



################## Fun��es ##################

# Fun��es para formata��es b�sicas dos dados do Finbra para cada ano.
FormataFinbra <- function(x, Ano, Aba){
  
  # Linhas de debug.
  # x <- MunicFinancas.New
  # Ano <- BDCamposFinbra.Select$FinbraCampo_Ano
  
  # Garante que o Ano � uma vari�vel inteira (integer).
  Ano <- as.integer(Ano)
  
  # Atribui os anos entre 1998 a 2012 para a fun��o "Fun2012_1998"
  FUN <- if(Ano <= 2012 & Ano >= 1998) "Fun2012_1998"
  
  # Caso o ano indicado n�o corresponder a nenhuma fun��o determinada, retorna erro.
  if(is.null(FUN)) {
    stop("Deve-se indicar um valor de ano com uma fun��o correspondente")
  }
  
  # fun��o para formatar os dados de 1998 a 2012.
  Fun2012_1998 <- function(x){
    
    Output <- x %>% 
      # Cria uma vari�vel uniformizada de indentifica��o dos munic�pios
      mutate(Munic_Id6 = paste0(CD_UF, str_pad(CD_MUN, 4, "left", "0"))) %>% 
      # Remove campos anteriores de indentifica��o dos munic�pios.
      select(-CD_UF, -CD_MUN) %>% 
      # Deixa a vari�vel de indentifica��o com a primeira coluna da tabela.
      select(Munic_Id6, everything())
  }
  
  # Fun��o gen�rica para consertar o banco (usando uma fun��o acima).
  GenericFunction <- function(x, FUN) {
    x <- get(FUN)(x)
  }
  
  # Executa a fun��o gen�rica para consertar o banco.
  Output <- GenericFunction(x, FUN)
  
  # Retorna o banco formatado.
  return(Output)
  
}


# Fun��o para transformar o c�digo municipal IBGE de seis d�gitos 
# em um c�digo de sete d�gitos.
MuncCod6To7 <- function(x, Munc6.Name, Munc7.Name, InputFolder) {
  
  # Linhas de debug:
  # x <- MunicFinancas.New
  # Munc6.Name <- "Munic_Id6"
  # Munc7.Name <- "Munic_Id"
  
  # Importa tabela com o c�digo dos munic�pios.
  Municipios <- fread(paste0(InputFolder, "Municipios.csv"), 
                      sep = ";", dec = ",", stringsAsFactors = FALSE)
  
  # seleciona apenas as colunas relevantes.
  Municipios <- Municipios %>% 
    select(Munic_Id, Munic_Id6)
  
  # Cria um banco com o c�digo municipal corrigido.
  Output <- x %>% 
    # Cria uma vari�vel "temp" com os mesmos valores do c�digo IBGE 6 dig.
    mutate_(.dots = setNames(list(Munc6.Name), "temp")) %>% 
    # Garante que essa vari�vel seja inteiros.
    mutate(temp = as.integer(temp)) %>% 
    # Insere banco com o c�digo de seis d�gitos.
    left_join(Municipios, by = c(temp = "Munic_Id6")) %>% 
    # Remove a vari�vel temp.
    select(-temp) %>% 
    # Coloca a vari�vel c�digo 7 dig como a primeira do banco.
    select(Munic_Id, everything()) %>% 
    # Remove antiga vari�vel com IBGE 6 dig.
    select(-matches(Munc6.Name))
  
  # Deixa a vari�vel de c�digo municipal com o nome determinado.
  names(Output)[1] <- Munc7.Name
  
  # Retorna banco com os c�digos corrigidos.
  return(Output)
}