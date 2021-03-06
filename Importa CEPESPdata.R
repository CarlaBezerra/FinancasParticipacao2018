# Script para Importar dados eleitorais do API CEPESPdata 

# Criado por Murilo Junqueira

# Data cria��o: 2018-03-01
# Ultima modifica��o: 2018-05-30

# Documenta��o do API: https://github.com/Cepesp-Fgv/cepesp-r 

################## Prepara �rea de trabalho ##################

# Limpa mem�ria
rm(list=ls(all=TRUE))
gc()

# Os diret�rios de inser��o dos dados Brutos (InputFolder), destino dos 
# dados (OutputFolder) e localiza��o dos scripts (ScriptFolder). Atualize se necess�rio!
InputFolder <- "E:/Users/Murilo/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Dados/Dados Brutos/Cepesp/"
OutputFolder <- "E:/Users/Murilo/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Dados/BD csv/"
ScriptFolder <- "E:/Users/Murilo/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Scripts R/"


# Como o API Cepesp grava informa��es no computador para agilizar repedi��es de extra��es,
# � importante selecionar o InputFolder como o diret�rio de trabalho. Certifique que esse 
# diret�rio � o adequado para receber informa��es novas (um diret�rio dedicado no Dropbox, por
# exemplo).
setwd(InputFolder)

# Verifica se o diret�rio de trabalho est� correto.
getwd()


# Instala Pacote do CEPESPdata. Se o pacote j� est� instalado, desabilite essas linhas.
# if (!require("devtools")) install.packages("devtools")
# devtools::install_github("Cepesp-Fgv/cepesp-r")

# Carrega os pacotes que ser�o usados nesse script.
library(cepespR)
library(tidyverse)
library(data.table)

################## CodeBook ##################

# C�digo da Situa��o Eleitoral	Descri��o da Situa��o Eleitoral
#   -7    Voto Nulo
#   -6    Voto em Branco
#   -5    Voto na Legenda
#   -1  	#NULO# (campo inv�lido por problemas de sistema)
#   1	    ELEITO
#   2	    SUPLENTE
#   3	    REN�NCIA/FALECIMENTO/CASSA��O ANTES DA ELEI��O
#   4	    N�O ELEITO
#   5	    M�DIA
#   6	    2� TURNO
#   7	    REN�NCIA/FALECIMENTO/CASSA��O AP�S A ELEI��O
#   8	    REGISTRO NEGADO ANTES DA ELEI��O
#   9	    REGISTRO NEGADO AP�S A ELEI��O
#   10	  SUBSTITU�DO
#   11	  INDEFERIDO COM RECURSO

################## Fun��es �teis ##################

CharaterToNumeric <- function(x) {
  x <- sub(",", ".", x)
  x <- as.numeric(x)
  return(x)
}

CharaterToInteger <- function(x) {
  x <- sub(",", ".", x)
  x <- as.integer(x)
  return(x)
}

################## Planilha CandidatoAno ##################

# Cria a planilha CandidatoAno, com os dados de vota��o por candidato para 
# as elei��es municipais.

# Seleciona os anos que ser�o buscados.
## Infelizmente, o ano de 2000 se encontra com um bug no API CepespData e por isso
## ser� baixado � parte, abaixo.
years <- c(2012, 2008, 2004)

# Cria uma tabela agregadora dos dados dos candidatos.
DadosCandidatos <- as_tibble()

# Loop para cada ano buscado.
for(i in seq_along(years)){
  
  # Linha debug:
  # i <- 1
  
  # Exibe o ano que se est� baixando.
  print(paste0("Baixando ano de ", years[i]))
  
  # Exibe que se est� buscando os dados dos candidatos a prefeito.
  print(paste0("Baixando dados dos candidatos prefeitos"))
  
  # Busca no API CEPESP os dados dos candidatos a prefeito.
  DadosRaw.CandPref <- candidates(year=years[i], position="Mayor", cached=TRUE)
  
  # Formata os dados dos candidatos a prefeito.
  DadosCandidatos.Prefeito.Ano <- DadosRaw.CandPref %>% 
    # Seleciona colunas relevantes.
    select(SIGLA_UE, NUM_TURNO, ANO_ELEICAO, NUMERO_CANDIDATO, NOME_CANDIDATO, 
           SIGLA_PARTIDO, CODIGO_LEGENDA, COD_SIT_TOT_TURNO) %>% 
    # Resolve problemas de classe
    mutate(COD_SIT_TOT_TURNO = CharaterToInteger(COD_SIT_TOT_TURNO)) %>% 
    # Retira candidatos sem situa��o eleitoral devido a impugna��o
    filter(!is.na(COD_SIT_TOT_TURNO)) %>% 
    # Retira casos de candidatos repetidos (n�o sei porque houve isso)
    arrange(SIGLA_UE, SIGLA_PARTIDO) %>% 
    distinct(SIGLA_UE, SIGLA_PARTIDO, NUM_TURNO, .keep_all = TRUE) %>% 
    # Retira candidatos sem situa��o eleitoral devido a impugna��o
    filter(!is.na(COD_SIT_TOT_TURNO)) %>% 
    # Garante que o CODIGO_LEGENDA (identifica��o da coliga��o) esteja em um 
    # formato amig�vel, retirando a nota��o cient�fica.
    mutate(CODIGO_LEGENDA = format(CODIGO_LEGENDA, scientific = FALSE)) %>% 
    mutate(CODIGO_LEGENDA = trimws(CODIGO_LEGENDA))
  
  # Libera a mem�ria.
  rm(DadosRaw.CandPref)
  
  # Busca no API CEPESP os dados das vota��es para prefeito
  DadosRaw.VotePref <- votes(year=years[i], position="Mayor", 
                             regional_aggregation="Municipality", cached=TRUE)
  
  # Libera a mem�ria. Essa vari�vel parece ser in�til. Provavel erro de c�digo do API CEPESP.
  rm(filter_index)
  
  # Formata dados dos candidatos e das vota��es
  DadosEleicao.Prefeito.Ano <- DadosRaw.VotePref %>% 
    # Seleciona colinas relevantes.
    select(SIGLA_UE, COD_MUN_IBGE, ANO_ELEICAO, DESCRICAO_CARGO, NUM_TURNO, 
           NUMERO_CANDIDATO, QTDE_VOTOS) %>% 
    # Insere dados sobre os candidatos.
    left_join(DadosCandidatos.Prefeito.Ano, by = c("SIGLA_UE", "NUM_TURNO", "ANO_ELEICAO",
                                                   "NUMERO_CANDIDATO"))  %>% 
    # Trata Brancos e Nulos
    mutate(COD_SIT_TOT_TURNO = as.integer(COD_SIT_TOT_TURNO)) %>% 
    mutate(COD_SIT_TOT_TURNO = ifelse(NUMERO_CANDIDATO == 95, -6, COD_SIT_TOT_TURNO)) %>% 
    mutate(COD_SIT_TOT_TURNO = ifelse(NUMERO_CANDIDATO == 96, -7, COD_SIT_TOT_TURNO)) %>% 
    # Ordena as vari�veis.
    select(COD_MUN_IBGE, ANO_ELEICAO, DESCRICAO_CARGO, NUM_TURNO, NUMERO_CANDIDATO, 
           NOME_CANDIDATO, SIGLA_PARTIDO, CODIGO_LEGENDA, QTDE_VOTOS, COD_SIT_TOT_TURNO)
  
  
  # Corrige o nome das vari�veis.
  names(DadosEleicao.Prefeito.Ano) <- c("Munic_Id",
                                        "CandAno_Ano",
                                        "CandAno_Cargo",
                                        "CandAno_Turno",
                                        "CandAno_Numero",
                                        "CandAno_Nome",
                                        "Partido_Sigla",
                                        "Coligacao_Id",
                                        "CandAno_QtVotos",
                                        "CandAno_SituacaoElec")
  
  # Libera a mem�ria.
  rm(DadosRaw.VotePref)
  rm(DadosCandidatos.Prefeito.Ano)
  
  # Exibe que se est� buscando os dados dos vereadores.
  print(paste0("Baixando dados dos candidatos vereadores"))
  
  # Busca no API CEPESP os dados dos candidatos a vereador.
  DadosRaw.CandVer <- candidates(year=years[i], position="Councillor", cached=TRUE)
  
  # Processa dados dos candidatos a vereador.
  DadosCandidatos.Vereador.Ano <- DadosRaw.CandVer %>% 
    # Seleciona colunas relevantes.
    select(SIGLA_UE, NUM_TURNO, ANO_ELEICAO, NUMERO_CANDIDATO, NOME_CANDIDATO, 
           NUMERO_PARTIDO, SIGLA_PARTIDO, CODIGO_LEGENDA, COD_SIT_TOT_TURNO) %>% 
    # Resolve problemas de classe
    mutate(COD_SIT_TOT_TURNO = CharaterToInteger(COD_SIT_TOT_TURNO)) %>% 
    # Retira candidatos sem situa��o eleitoral devido a impugna��o
    filter(!is.na(COD_SIT_TOT_TURNO)) %>% 
    # Retira casos de candidatos repetidos (n�o sei porque houve isso)
    arrange(SIGLA_UE, NUMERO_CANDIDATO) %>% 
    distinct(SIGLA_UE, NUMERO_CANDIDATO, NUM_TURNO, .keep_all = TRUE) %>% 
    # Retira candidatos sem situa��o eleitoral devido a impugna��o
    filter(!is.na(COD_SIT_TOT_TURNO)) %>% 
    # Garante que o CODIGO_LEGENDA (identifica��o da coliga��o) esteja em um 
    # formato amig�vel, retirando a nota��o cient�fica.
    mutate(CODIGO_LEGENDA = format(CODIGO_LEGENDA, scientific = FALSE)) %>% 
    mutate(CODIGO_LEGENDA = trimws(CODIGO_LEGENDA))
  
  # Libera a mem�ria
  rm(DadosRaw.CandVer)
  
  # Busca no API CEPESP os dados das vota��es para vereador.
  DadosRaw.VoteVer <- votes(year=years[i], position="Councillor", 
                            regional_aggregation="Municipality", cached=TRUE)
  # Libera mom�ria
  rm(filter_index)
  
  # Formata dados dos candidatos e das vota��es.
  DadosEleicao.Vereador.Ano <- DadosRaw.VoteVer %>% 
    # Seleciona colunas relevantes.
    select(SIGLA_UE, COD_MUN_IBGE, ANO_ELEICAO, DESCRICAO_CARGO, NUM_TURNO, 
           NUMERO_CANDIDATO, QTDE_VOTOS) %>% 
    # Insere dados sobre os candidatos.
    left_join(DadosCandidatos.Vereador.Ano, by = c("SIGLA_UE", "NUM_TURNO", "ANO_ELEICAO",
                                                   "NUMERO_CANDIDATO")) %>% 
    # Trata os votos em legenda.
    arrange(COD_MUN_IBGE, ANO_ELEICAO, as.character(NUMERO_CANDIDATO)) %>% 
    mutate(COD_SIT_TOT_TURNO = as.integer(COD_SIT_TOT_TURNO)) %>% 
    mutate(COD_SIT_TOT_TURNO = ifelse(nchar(as.character(NUMERO_CANDIDATO)) == 2, -5, COD_SIT_TOT_TURNO))  %>% 
    mutate(NUMERO_PARTIDO = ifelse(nchar(as.character(NUMERO_CANDIDATO)) == 2, NUMERO_CANDIDATO, NUMERO_PARTIDO)) %>% 
    mutate(CODIGO_LEGENDA = ifelse(nchar(as.character(NUMERO_CANDIDATO)) == 2 & NUMERO_PARTIDO == lead(NUMERO_PARTIDO), 
                                   lead(CODIGO_LEGENDA), CODIGO_LEGENDA)) %>% 
    # Garante que a Sigla do partido n�o � factor
    mutate(SIGLA_PARTIDO = as.character(SIGLA_PARTIDO)) %>% 
    mutate(SIGLA_PARTIDO = ifelse(nchar(as.character(NUMERO_CANDIDATO)) == 2 & NUMERO_PARTIDO == lead(NUMERO_PARTIDO), 
                                   lead(SIGLA_PARTIDO), SIGLA_PARTIDO)) %>% 
    # Trata Brancos e Nulos
    mutate(COD_SIT_TOT_TURNO = ifelse(NUMERO_CANDIDATO == 95, -6, COD_SIT_TOT_TURNO)) %>% 
    mutate(COD_SIT_TOT_TURNO = ifelse(NUMERO_CANDIDATO == 96, -7, COD_SIT_TOT_TURNO)) %>% 
    # Ordena as vari�veis.
    select(COD_MUN_IBGE, ANO_ELEICAO, DESCRICAO_CARGO, NUM_TURNO, NUMERO_CANDIDATO, 
           NOME_CANDIDATO, SIGLA_PARTIDO, CODIGO_LEGENDA, QTDE_VOTOS, COD_SIT_TOT_TURNO)
  
  # Libera a mem�ria.
  rm(DadosCandidatos.Vereador.Ano)
  rm(DadosRaw.VoteVer)

  # Corrige o nome das vari�veis.
  names(DadosEleicao.Vereador.Ano) <- c("Munic_Id",
                                        "CandAno_Ano",
                                        "CandAno_Cargo",
                                        "CandAno_Turno",
                                        "CandAno_Numero",
                                        "CandAno_Nome",
                                        "Partido_Sigla",
                                        "Coligacao_Id",
                                        "CandAno_QtVotos",
                                        "CandAno_SituacaoElec")
  
  # Empilha os dados sobre os prefeitos e sobre os vereadores.
  DadosCandidatos.Ano <- rbind(DadosEleicao.Prefeito.Ano, DadosEleicao.Vereador.Ano) %>% 
    # Um pequeno truque para diminuir o tamanho do banco.
    mutate(CandAno_Cargo = as.character(CandAno_Cargo)) %>% 
    mutate(CandAno_Cargo = substr(CandAno_Cargo, 1, 1))
  
  # Libera a mem�ria.
  rm(DadosEleicao.Prefeito.Ano, DadosEleicao.Vereador.Ano)
  
  # Uniformiza os c�digos de situa��o eleitoral
  if (years[i] >= 2012) {
    DadosCandidatos.Ano <- DadosCandidatos.Ano %>% 
      mutate(CandAno_SituacaoElec = ifelse(CandAno_Cargo == "V" & CandAno_SituacaoElec == 2, 1, CandAno_SituacaoElec)) %>% 
      mutate(CandAno_SituacaoElec = ifelse(CandAno_Cargo == "V" & CandAno_SituacaoElec == 5, 2, CandAno_SituacaoElec)) %>% 
      mutate(CandAno_SituacaoElec = ifelse(CandAno_Cargo == "V" & CandAno_SituacaoElec == 3, 5, CandAno_SituacaoElec)) 
  }
  
  
  # insere dados na tabela de agrega��o principai.
  DadosCandidatos <- rbind(DadosCandidatos, DadosCandidatos.Ano)
  
  # Libera a mem�ria.
  rm(DadosCandidatos.Ano)
  gc()
}
# Libera a mem�ria.
rm(i, years)

# Caminho do arquivo de Output.
pathFile <- paste0(OutputFolder, "CandidatoAno.csv")

# Grava o arquivo  
write.table(DadosCandidatos, file = pathFile, sep = ";", dec = ",", 
            row.names=FALSE, append = FALSE)

# Libera a mem�ria.
rm(pathFile, DadosCandidatos)
gc()





################## Inser��o dos dados de Candidato/Ano de 2000 ##################

# Como o API Cepesp est� apresentando problemas para baixar os dados sobre os candidatos
# a vereador no ano de 2000. Assim, eu baixei os dados diretamente do site CepespData 
# (cepesp.io) e processei os dados por aqui.


# Tenta mais uma vez extrair os dados com o API do CepespData.
DadosRaw.CandVer <- candidates(year=2000, position="Councillor", cached=TRUE)

# Testa para ver se os dados est�o OK.
class(DadosRaw.CandVer)
dim(DadosRaw.CandVer)

# Se os dados acima n�o estiverem funcionando, usar o arquivo extraido do site do Cepesp.
DadosRaw.CandVer <- fread(paste0(InputFolder, "CANDIDATOS_VEREADOR_2000.csv"),
                   stringsAsFactors = FALSE, encoding = "UTF-8")

# Libera mem�ria.
rm(filter_index)

# Testa para ver se os dados est�o OK.
class(DadosRaw.CandVer)
dim(DadosRaw.CandVer)
names(DadosRaw.CandVer)


# Seleciona e formata os dados.
DadosCandidatos.Vereador.Ano <- DadosRaw.CandVer %>% 
  # Seleciona as colunas relevantes.
  select(SIGLA_UE, NUM_TURNO, ANO_ELEICAO, NUMERO_CANDIDATO, NOME_CANDIDATO, 
         SIGLA_PARTIDO, NUMERO_PARTIDO, CODIGO_LEGENDA, COD_SIT_TOT_TURNO) %>% 
  # Resolve problemas de classe
  mutate(COD_SIT_TOT_TURNO = CharaterToInteger(COD_SIT_TOT_TURNO)) %>% 
  # Retira candidatos sem situa��o eleitoral devido a impugna��o
  filter(!is.na(COD_SIT_TOT_TURNO)) %>% 
  # Retira casos de candidatos repetidos (n�o sei porque houve isso)
  arrange(SIGLA_UE, NUMERO_CANDIDATO) %>% 
  distinct(SIGLA_UE, NUMERO_CANDIDATO, NUM_TURNO, .keep_all = TRUE) %>% 
  # Garante que o CODIGO_LEGENDA (identifica��o da coliga��o) esteja em um 
  # formato amig�vel, retirando a nota��o cient�fica.
  mutate(CODIGO_LEGENDA = format(CODIGO_LEGENDA, scientific = FALSE)) %>% 
  mutate(CODIGO_LEGENDA = trimws(CODIGO_LEGENDA))

# Testa para ver se os dados est�o OK.
head(DadosCandidatos.Vereador.Ano)
names(DadosCandidatos.Vereador.Ano)
dim(DadosCandidatos.Vereador.Ano)
# View(DadosCandidatos.Vereador.Ano)

# Retira os dados brutos (libera mem�ria).
rm(DadosRaw.CandVer)

# Baixa os dados de vota��o (esses est�o funcionando no API CepespData)
DadosRaw.VoteVer <- votes(year = 2000, position = "Councillor", 
                          regional_aggregation = "Municipality", cached=TRUE)
rm(filter_index)

# Testa para ver se os dados est�o OK.
names(DadosRaw.VoteVer)
head(DadosRaw.VoteVer)

# Mescla os dados de candidatos e vota��o.
DadosEleicao.Vereador.Ano <- DadosRaw.VoteVer %>% 
  # Seleciona as colunas relevantes.
  select(SIGLA_UE, COD_MUN_IBGE, ANO_ELEICAO, DESCRICAO_CARGO, NUM_TURNO, 
         NUMERO_CANDIDATO, QTDE_VOTOS) %>% 
  # Insere dados sobre os candidatos.
  left_join(DadosCandidatos.Vereador.Ano, by = c("SIGLA_UE", "NUM_TURNO", "ANO_ELEICAO",
                                                 "NUMERO_CANDIDATO")) %>% 
  # Trata os votos em legenda.
  arrange(COD_MUN_IBGE, ANO_ELEICAO, as.character(NUMERO_CANDIDATO)) %>% 
  mutate(COD_SIT_TOT_TURNO = as.integer(COD_SIT_TOT_TURNO)) %>% 
  mutate(COD_SIT_TOT_TURNO = ifelse(nchar(as.character(NUMERO_CANDIDATO)) == 2, -5, COD_SIT_TOT_TURNO))  %>% 
  mutate(NUMERO_PARTIDO = ifelse(nchar(as.character(NUMERO_CANDIDATO)) == 2, NUMERO_CANDIDATO, NUMERO_PARTIDO)) %>% 
  mutate(CODIGO_LEGENDA = ifelse(nchar(as.character(NUMERO_CANDIDATO)) == 2 & NUMERO_PARTIDO == lead(NUMERO_PARTIDO), 
                                 lead(CODIGO_LEGENDA), CODIGO_LEGENDA)) %>% 
  # Garante que a Sigla do partido n�o � factor
  mutate(SIGLA_PARTIDO = as.character(SIGLA_PARTIDO)) %>% 
  mutate(SIGLA_PARTIDO = ifelse(nchar(as.character(NUMERO_CANDIDATO)) == 2 & NUMERO_PARTIDO == lead(NUMERO_PARTIDO), 
                                lead(SIGLA_PARTIDO), SIGLA_PARTIDO)) %>% 
  # Trata Brancos e Nulos
  mutate(COD_SIT_TOT_TURNO = ifelse(NUMERO_CANDIDATO == 95, -6, COD_SIT_TOT_TURNO)) %>% 
  mutate(COD_SIT_TOT_TURNO = ifelse(NUMERO_CANDIDATO == 96, -7, COD_SIT_TOT_TURNO)) %>% 
  # Ordena as vari�veis.
  select(COD_MUN_IBGE, ANO_ELEICAO, DESCRICAO_CARGO, NUM_TURNO, NUMERO_CANDIDATO, 
         NOME_CANDIDATO, SIGLA_PARTIDO, CODIGO_LEGENDA, QTDE_VOTOS, COD_SIT_TOT_TURNO)


# Libera Mem�ria.
rm(DadosCandidatos.Vereador.Ano)
rm(DadosRaw.VoteVer)

# Corrige nomes.
names(DadosEleicao.Vereador.Ano) <- c("Munic_Id",
                                      "CandAno_Ano",
                                      "CandAno_Cargo",
                                      "CandAno_Turno",
                                      "CandAno_Numero",
                                      "CandAno_Nome",
                                      "Partido_Sigla",
                                      "Coligacao_Id",
                                      "CandAno_QtVotos",
                                      "CandAno_SituacaoElec")

# Observa os dados.
# View(DadosEleicao.Vereador.Ano)

# Agora carrega os dados dos candidatos a prefeito em 2000.

# Busca no API CEPESP os dados dos candidatos a prefeito.
DadosRaw.CandPref <- candidates(year=2000, position="Mayor", cached=TRUE)

# View(DadosRaw.CandPref)


# Formata os dados dos candidatos a prefeito.
DadosCandidatos.Prefeito.Ano <- DadosRaw.CandPref %>% 
  # Seleciona colunas relevantes.
  select(SIGLA_UE, NUM_TURNO, ANO_ELEICAO, NUMERO_CANDIDATO, NOME_CANDIDATO, 
         SIGLA_PARTIDO, CODIGO_LEGENDA, COD_SIT_TOT_TURNO) %>% 
  # Resolve problemas de classe
  mutate(COD_SIT_TOT_TURNO = CharaterToInteger(COD_SIT_TOT_TURNO)) %>% 
  # Retira candidatos sem situa��o eleitoral devido a impugna��o
  filter(!is.na(COD_SIT_TOT_TURNO)) %>% 
  # Retira casos de candidatos repetidos (n�o sei porque houve isso)
  arrange(SIGLA_UE, NUMERO_CANDIDATO) %>% 
  distinct(SIGLA_UE, SIGLA_PARTIDO, NUM_TURNO, .keep_all = TRUE) %>% 
  # Garante que o CODIGO_LEGENDA (identifica��o da coliga��o) esteja em um 
  # formato amig�vel, retirando a nota��o cient�fica.
  mutate(CODIGO_LEGENDA = format(CODIGO_LEGENDA, scientific = FALSE)) %>% 
  mutate(CODIGO_LEGENDA = trimws(CODIGO_LEGENDA))


# Libera a mem�ria.
rm(DadosRaw.CandPref)

# Busca no API CEPESP os dados das vota��es para prefeito
DadosRaw.VotePref <- votes(year=2000, position="Mayor", 
                           regional_aggregation="Municipality", cached=TRUE)

# Libera a mem�ria. Essa vari�vel parece ser in�til. Provavel erro de c�digo do API CEPESP.
rm(filter_index)


# Formata dados dos candidatos e das vota��es
DadosEleicao.Prefeito.Ano <- DadosRaw.VotePref %>% 
  # Seleciona colinas relevantes.
  select(SIGLA_UE, COD_MUN_IBGE, ANO_ELEICAO, DESCRICAO_CARGO, NUM_TURNO, 
         NUMERO_CANDIDATO, QTDE_VOTOS) %>% 
  # Insere dados sobre os candidatos.
  left_join(DadosCandidatos.Prefeito.Ano, by = c("SIGLA_UE", "NUM_TURNO", "ANO_ELEICAO",
                                                 "NUMERO_CANDIDATO")) %>% 
  # Trata Brancos e Nulos
  mutate(COD_SIT_TOT_TURNO = as.integer(COD_SIT_TOT_TURNO)) %>% 
  mutate(COD_SIT_TOT_TURNO = ifelse(NUMERO_CANDIDATO == 95, -6, COD_SIT_TOT_TURNO)) %>% 
  mutate(COD_SIT_TOT_TURNO = ifelse(NUMERO_CANDIDATO == 96, -7, COD_SIT_TOT_TURNO)) %>% 
  # Ordena as vari�veis.
  select(COD_MUN_IBGE, ANO_ELEICAO, DESCRICAO_CARGO, NUM_TURNO, NUMERO_CANDIDATO, 
         NOME_CANDIDATO, SIGLA_PARTIDO, CODIGO_LEGENDA, QTDE_VOTOS, COD_SIT_TOT_TURNO)

# Corrige o nome das vari�veis.
names(DadosEleicao.Prefeito.Ano) <- c("Munic_Id",
                                      "CandAno_Ano",
                                      "CandAno_Cargo",
                                      "CandAno_Turno",
                                      "CandAno_Numero",
                                      "CandAno_Nome",
                                      "Partido_Sigla",
                                      "Coligacao_Id",
                                      "CandAno_QtVotos",
                                      "CandAno_SituacaoElec")

# Libera a mem�ria.
rm(DadosRaw.VotePref)
rm(DadosCandidatos.Prefeito.Ano)

# View(DadosEleicao.Vereador.Ano)

# Empilha os dados sobre os prefeitos e sobre os vereadores.
DadosCandidatos.Ano <- rbind(DadosEleicao.Prefeito.Ano, DadosEleicao.Vereador.Ano) %>%
  # Um pequeno truque para diminuir o tamanho do banco.
  mutate(CandAno_Cargo = as.character(CandAno_Cargo)) %>% 
  mutate(CandAno_Cargo = substr(CandAno_Cargo, 1, 1))

# Libera Mem�ria.
rm(DadosEleicao.Prefeito.Ano, DadosEleicao.Vereador.Ano)

# Carrega os dados j� processados.
DadosEleicao <- fread(paste0(OutputFolder, "CandidatoAno.csv"), 
                      sep = ";", dec = ",",
                      stringsAsFactors = FALSE)


# Evita duplica��o de dados.
DadosEleicao <- DadosEleicao %>% 
  filter(CandAno_Ano != 2000)

# Verifica se os dados de 2000 foram realmente extraidos.
table(DadosEleicao$CandAno_Ano)

# Empilha os dados antigos e os novos.
DadosEleicao.Bind <- rbind(DadosEleicao, DadosCandidatos.Ano)

# Libera mem�ria.
rm(DadosEleicao, DadosCandidatos.Ano)

# Verifia disposi��o dos dados.
table(DadosEleicao.Bind$CandAno_Ano)

# Grava o arquivo.
write.table(DadosEleicao.Bind, file = paste0(OutputFolder, "CandidatoAno.csv"), 
            sep = ";", dec = ",", 
            row.names=FALSE, append = FALSE)

# Libera a mem�ria.
rm(DadosEleicao.Bind)
gc()



################## Tabela De/Para EU-Cod_Munic do IBGE ##################


# Faz a tabela De/Para de Sigla da unidade eleitoral (UE) para Cod_Munic do IBGE.

# Baixa os dados da elei��o de 2012, como refer�ncia para a UE e para o  Cod_Munic do IBGE.
DadosRaw.VotePref <- votes(year=2012, position="Mayor", 
                           regional_aggregation="Municipality", cached=TRUE)

# Libera mem�ria.
rm(filter_index)

# Verifica os dados da tabela.
names(DadosRaw.VotePref)
head(UEToCodIBGE)

# Extrai a tabela De/Para COD_MUN_IBGE - SIGLA_UE.
UEToCodIBGE <- DadosRaw.VotePref %>% 
  # Seleciona apenas as colunas do c�digo IBGE e da silha UE.
  select(COD_MUN_IBGE, SIGLA_UE) %>% 
  # # Linhas diplicadas.
  distinct(COD_MUN_IBGE, SIGLA_UE) %>% 
  # Ordena pelo c�digo IBGE.
  arrange(COD_MUN_IBGE) %>% 
  # Muda o nome da vari�vel do c�digo IBGE.
  rename(Munic_Id = COD_MUN_IBGE)

# Verifica os dados da tabela.
names(UEToCodIBGE)
head(UEToCodIBGE)

# Grava o arquivo  
write.table(UEToCodIBGE, file = paste0(OutputFolder, "UEToCodIBGE.csv"), sep = ";", dec = ",", 
            row.names=FALSE, append = FALSE)

# Libera Mem�ria
rm(DadosRaw.VotePref, UEToCodIBGE)



################## Tabela Coligacoes ##################

# Extrai os dados da tabela "ColigacoesPartidos.csv" e "Coliga��es.csv"

# Tabela de tradu��o da Unidade eleitoral para o c�digo municipal IBGE
UEToCodIBGE <- fread(paste0(OutputFolder, "UEToCodIBGE.csv"), 
                     sep = ";", dec = ",", stringsAsFactors = FALSE)

# Garante que a sigla_UE � uma vari�vel texto.
UEToCodIBGE$SIGLA_UE <- as.character(UEToCodIBGE$SIGLA_UE)

# Vetor com os anos da extra��o.
years <- c(2012, 2008, 2004, 2000)

# Cria banco de dados para a extra��o dos dados das coliga��es e dos partidos.
DadosColigacoes <- as_tibble()
ColigacoesPartidos <- as_tibble()

# Loop para cada ano da amostra.
for (i in seq_along(years)) {
  
  # Linha de debug:
  # i <- 1
  
  # Exibe o ano que est� sendo processado.
  print(paste0("Baixando dados do ano de ", years[i]))
  
  # Exibe progresso do c�digo.
  print("Baixando dados de coliga��es")
  
  # Baixa os dados das coliga��es dos prefeitos e vereadores.
  DadosRaw.ColgPref.ano <- coalitions(year=years[i], position="Mayor", cached=TRUE)
  DadosRaw.ColgVer.ano <- coalitions(year=years[i], position="Councillor", cached=TRUE)
  rm(filter_index)
  
  # Retira uma enigm�tica coluna (row.name?)
  DadosRaw.ColgPref.ano$X <- NULL
  DadosRaw.ColgVer.ano$X <- NULL
  
  
  # Formata os dados das colina��es dos prefeitos.
  DadosEleicao.Coligacao.Ano <- rbind(DadosRaw.ColgPref.ano, DadosRaw.ColgVer.ano)  %>% 
    # Seleciona as colunas relevantes.
    select(SEQUENCIAL_COLIGACAO, SIGLA_UE, ANO_ELEICAO, DESCRICAO_CARGO, 
           CODIGO_CARGO, NOME_COLIGACAO, COMPOSICAO_COLIGACAO) %>% 
    # Deixa o n�mero da coliga��o mais amigavel.
    mutate(SEQUENCIAL_COLIGACAO = format(SEQUENCIAL_COLIGACAO, scientific = FALSE)) %>% 
    mutate(SEQUENCIAL_COLIGACAO = trimws(SEQUENCIAL_COLIGACAO)) %>% 
    # Transforma a sigla da UE em vari�vel texto.
    mutate(SIGLA_UE = as.character(SIGLA_UE)) %>% 
    # insere a tabela de De/Para entre siglaUE e Cod_Munic IBGE.
    left_join(UEToCodIBGE, by = "SIGLA_UE") %>% 
    # Remove a sigla UE
    select(-SIGLA_UE) %>% 
    # Muda a ordem das vari�veis.
    select(SEQUENCIAL_COLIGACAO, Munic_Id, everything()) %>% 
    # Ordena o banco pelo ano da elei��o, munic�pio, cargo e coliga��o.
    arrange(ANO_ELEICAO, Munic_Id, DESCRICAO_CARGO, SEQUENCIAL_COLIGACAO) %>% 
    # Remove duplicatas de coliga��o.
    distinct(SEQUENCIAL_COLIGACAO, .keep_all = TRUE)
  
  # Altera o nome das vari�veis.
  names(DadosEleicao.Coligacao.Ano) <- c("Coligacao_Id",
                                        "Munic_Id",
                                        "Coligacao_Ano",
                                        "Coligacao_Cargo",
                                        "Coligacao_Turno",
                                        "Coligacao_Nome",
                                        "Coligacao_composicao")
  
  # Exibe progresso do c�digo.
  print("Baixando dados de coliga��es-Partidos")
  
  # Formata os dados das coliga��es.
  ColigacoesPartidos.Ano <- rbind(DadosRaw.ColgPref.ano, DadosRaw.ColgVer.ano) %>% 
    # Seleciona colunas relevantes.
    select(SEQUENCIAL_COLIGACAO, NUMERO_PARTIDO, ANO_ELEICAO) %>%
    # Deixa o n�mero da coliga��o mais amigavel.
    mutate(SEQUENCIAL_COLIGACAO = format(SEQUENCIAL_COLIGACAO, scientific = FALSE)) %>% 
    mutate(SEQUENCIAL_COLIGACAO = trimws(SEQUENCIAL_COLIGACAO)) %>% 
    # Ordena por n�mero da coliga��o.
    arrange(SEQUENCIAL_COLIGACAO)
  
  
  
  names(ColigacoesPartidos.Ano) <- c("Coligacao_Id",
                                     "Partido_Id",
                                     "Coligacao_Ano")
  
  # Libera Mem�ria
  rm(DadosRaw.ColgPref.ano, DadosRaw.ColgVer.ano)
  
  # Agrega as extra��es do ano nas tabelas agregadoras
  DadosColigacoes <- rbind(DadosColigacoes, DadosEleicao.Coligacao.Ano)
  ColigacoesPartidos <- rbind(ColigacoesPartidos, ColigacoesPartidos.Ano)
  
  # Libera Mem�ria
  rm(DadosEleicao.Coligacao.Ano, ColigacoesPartidos.Ano)
  gc()
}
# Libera Mem�ria
rm(i, years)



# Grava o arquivo com os dados das coliga��es
write.table(DadosColigacoes, file = paste0(OutputFolder, "Coligacoes.csv"), 
            sep = ";", dec = ",", 
            row.names=FALSE, append = FALSE)

# Grava o arquivo com os dados ColigacoesPartidos
write.table(ColigacoesPartidos, file = paste0(OutputFolder, "ColigacoesPartidos.csv"), 
            sep = ";", dec = ",", 
            row.names=FALSE, append = FALSE)

# Libera Mem�ria
rm(DadosColigacoes, ColigacoesPartidos)
rm(UEToCodIBGE)
gc()



################## Tabela Partidos ##################


# Cria a planilha Partidos.csv, com os dados sobre os partidos pol�ticos.

# Seleciona os anos que ser�o buscados.
years <- c(2012, 2008, 2004, 2000)

# Carrega dados eleitorais
# Data about candidates
CandidatoAno <- fread(paste0(OutputFolder, "CandidatoAno.csv"), 
                      sep = ";", dec = ",",
                      stringsAsFactors = FALSE)


# Cria uma tabela agregadora dos dados dos partidos.
Partidos <- as_tibble()


# Loop para cada ano buscado.
for(i in seq_along(years)){
  
  # Linha debug:
  # i <- 1
  
  # Exibe o ano que se est� baixando.
  print(paste0("Baixando ano de ", years[i]))
  
  # Baixa os dados das coliga��es dos prefeitos e vereadores.
  DadosRaw.ColgPref.ano <- coalitions(year=years[i], position="Mayor", cached=TRUE)
  DadosRaw.ColgVer.ano <- coalitions(year=years[i], position="Councillor", cached=TRUE)
  rm(filter_index)

  # Retira uma enigm�tica coluna (row.name?)
  DadosRaw.ColgPref.ano <- DadosRaw.ColgPref.ano %>% select(-starts_with("X"))
  DadosRaw.ColgVer.ano <- DadosRaw.ColgVer.ano %>% select(-starts_with("X"))
  
  # Separa apenas os dados dos partidos.
  DadosEleicao.Partidos.Ano <- rbind(DadosRaw.ColgPref.ano, DadosRaw.ColgVer.ano)  %>% 
    # Seleciona colunas relevantes.
    select(NOME_PARTIDO, SIGLA_PARTIDO, NUMERO_PARTIDO, ANO_ELEICAO) %>% 
    # Exclui repeti��es de partidos.
    distinct(NUMERO_PARTIDO, SIGLA_PARTIDO, .keep_all = TRUE) %>% 
    # Cria uma coluna identificadora do partido (numero_sigla sem espa�o).
    mutate(Partido_Id = paste0(NUMERO_PARTIDO, "_",gsub(" ", "", SIGLA_PARTIDO))) %>% 
    # Coloca a coluna identificadora em primeiro lugar
    select(Partido_Id, everything())

  
  # Libera a mem�ria.
  rm(DadosRaw.ColgPref.ano, DadosRaw.ColgVer.ano)
  
  # Corrige o nome das vari�veis.
  names(DadosEleicao.Partidos.Ano) <- c("Partido_Id",
                                        "Partido_Nome",
                                        "Partido_Sigla",
                                        "Partido_Numero",
                                        "ANO_ELEICAO")
  
  
  # Empilha os dados sobre os prefeitos e sobre os vereadores.
  Partidos <- rbind(Partidos, DadosEleicao.Partidos.Ano)
  
  # Libera a mem�ria.
  rm(DadosEleicao.Partidos.Ano)
  gc()
}
# Libera a mem�ria.
rm(i, years)


# Adiciona o ano de 1996
DadosEleicao.Partidos.1996 <- CandidatoAno  %>% 
  # filtra o ano de 1996
  filter(CandAno_Ano == 1996) %>% 
  # Uniformiza os nomes.
  rename(ANO_ELEICAO = CandAno_Ano) %>% 
  # Extrai o n�mero do partido
  mutate(Partido_Numero = substr(as.character(CandAno_Numero), 1, 2)) %>%
  # Seleciona colunas relevantes.
  select(Partido_Sigla, Partido_Numero, ANO_ELEICAO) %>% 
  # Corrige o caso do PRONA
  mutate(Partido_Sigla = ifelse(Partido_Numero == 56, "PRONA", Partido_Sigla)) %>% 
  # Exclui repeti��es de partidos.
  distinct(Partido_Numero, Partido_Sigla, .keep_all = TRUE) %>% 
  # Cria uma coluna identificadora do partido (numero_sigla sem espa�o).
  mutate(Partido_Id = paste0(Partido_Numero, "_",gsub(" ", "", Partido_Sigla))) %>% 
  # Coloca a coluna identificadora em primeiro lugar
  select(Partido_Id, everything()) %>% 
  left_join(Partidos, by = "Partido_Id",  suffix = c("", ".y")) %>% 
  select(names(Partidos))


# Cria o banco final, colocando a primeira e �ltima vez que o partido aparece no banco.
Partidos.Format <- rbind(Partidos, DadosEleicao.Partidos.1996) %>%
  # remove repeti��es
  arrange(ANO_ELEICAO) %>% 
  distinct(Partido_Numero, Partido_Sigla, ANO_ELEICAO, .keep_all = TRUE) %>% 
  # Garante que o ano da elei��o � inteiro (integer).
  mutate(ANO_ELEICAO = as.integer(ANO_ELEICAO)) %>% 
  # Agrupa os dados por partido
  group_by(Partido_Id) %>% 
  # Coloca os anos onde o partido surgiu pela primeira e �ltima vez.
  mutate(Partido_AnoInicial = min(ANO_ELEICAO)) %>% 
  mutate(Partido_AnoFinal = max(ANO_ELEICAO)) %>% 
  # Retira a vari�vel ano.
  select(-ANO_ELEICAO) %>%
  # Retira o agrupamento.
  ungroup() %>% 
  # Faz com que cada partido apare�a uma �nica vez.
  distinct(Partido_Id, .keep_all = TRUE) %>% 
  # Ordena os dados por n�mero do partido
  arrange(Partido_Numero)

# Observa o banco de dados gerado.
names(Partidos.Format)
dim(Partidos.Format)
head(Partidos.Format)
View(Partidos.Format)

# Caminho do arquivo de Output.
pathFile <- paste0(OutputFolder, "Partidos.csv")

# Grava o arquivo  
write.table(Partidos.Format, file = pathFile, sep = ";", dec = ",", 
            row.names=FALSE, append = FALSE)

# Libera a mem�ria.
rm(pathFile, Partidos.Format, Partidos)
gc()

# End