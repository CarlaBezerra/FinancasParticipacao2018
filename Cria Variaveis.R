
# Script para extrair dados do BD para a an�lise das finan�as municipais
# e do probabilidade de sobreviv�ncia do Or�amento Participativo.

# Criado por Murilo Junqueira

# Data cria��o: 2018-03-15
# Ultima modifica��o: 2018-03-15

################## Prepara �rea de trabalho ##################

#clean memory
rm(list=ls(all=TRUE))
gc()


# Os diret�rios de inser��o dos dados Brutos (InputFolder), destino dos 
# dados (OutputFolder) e localiza��o dos scripts (ScriptFolder). Atualize se necess�rio!
InputFolder <- "C:/Users/mjunqueira/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Dados/BD csv/"
OutputFolder <- "C:/Users/mjunqueira/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Dados/Dados An�lise/"
ScriptFolder <- "C:/Users/mjunqueira/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Scripts R/"
SpadaFolder <- "C:/Users/mjunqueira/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Dados/Dados Brutos/PBCENSUS Spada/"

# instala o pacote de extra��o dos dados, se necess�rio
library(tidyverse)
library(data.table)
library(readstata13)
library(scales)

################## Fun��es de Trabalho ##################

# fun��o para comparar dois bancos de dados:

ComparaBancos <- function(DFs, Id_Vars, Compare_Vars) {
  # DFs <- list(Data, Spada.Data)
  # Id_Vars <- list("Munic_Id" = "codeipea", "year" = "year")
  # Compare_Vars <- list("SocioMunic_Populacao" = "pop", "Munic_Nome" = "Munic�pio")
  
  # Seleciona as vari�veis relevantes (vari�veis de identifica��o e de compara��o)
  DF1 <- DFs[[1]] %>% 
    select(names(Id_Vars), names(Compare_Vars))
  
  # Seleciona as vari�veis relevantes (vari�veis de identifica��o e de compara��o)
  DF2 <- DFs[[2]] %>% 
    select(as.character(Id_Vars), as.character(Compare_Vars))
  
  # harmoniza as classes das vari�veis
  DF2 <- map2_dfr(DF2, map_chr(DF1, class), as)
  
  # Igualiza os nomes.
  names(DF2) <- names(DF1)
  
  # Une os dois bancos
  ComparaValores <- DF1 %>% 
    left_join(DF2, by = names(Id_Vars))
  
  # Compara o valores das vari�veis dos dois bancos
  for (i in seq_along(Compare_Vars)) {
    # i <- 1
    # Linha de comando para comparar as vari�veis.
    LinhaComando <- paste0(names(Compare_Vars)[i], " = ", "ifelse(", names(Compare_Vars)[i] , ".x",
                           " == ", names(Compare_Vars)[i] , ".y, TRUE, FALSE)")
    
    # Cria vari�vel de compara��o
    ComparaValores <- ComparaValores %>% 
      mutate_(.dots = LinhaComando)
    
    # Resolve o problema do nome esquisito que fica;
    names(ComparaValores)[ncol(ComparaValores)] <- names(Compare_Vars)[i]
    
  }
  
  # Deixa apenas as vari�veis de compara��o no banco.
  ComparaValores <- ComparaValores %>% 
    select(names(Compare_Vars))
  
  
  # Soma as vari�veis que s�o correspondentes (matches)
  Comparacao <- rbind(map_int(ComparaValores, sum, na.rm = TRUE)) %>% 
    # Soma as vari�veis missing (NA)
    # rbind(map_int(ComparaValores, function(x) sum(is.na(x)))) %>% 
    rbind(map_int(names(Compare_Vars), function(x) sum(is.na(DF1[[x]])))) %>% 
    rbind(map_int(names(Compare_Vars), function(x) sum(is.na(DF2[[x]])))) %>% 
    as.data.frame() %>% 
    # Cria linha de legenda.
    cbind(as.data.frame(list(Desc = c("Matchs", "NAs DF1", "NAs DF2")))) %>% 
    # Coloca a legenda na primeira coluna
    select(Desc, everything()) %>% 
    # Transforma em decimal
    mutate_at(names(Compare_Vars), function(x) x/nrow(ComparaValores)) %>% 
    # Formata em percentual.
    mutate_at(names(Compare_Vars), percent) 
  
  Comparacao
}



################## Cria Vari�veis de An�lise ##################

# Dados Originais do Spada, para compara��o.
Spada.Data <- read.dta13(paste0(SpadaFolder, "PBCENSUS1989_2012data.dta"))

names(Spada.Data)

# Podemos ver que Spada adiciona quase todos os munic�pios (5592) entre 2004 e 2012
table(Spada.Data$year)


# Tamb�m Adiciona c�digo IBGE municipal, nome do munic�pios, estado e popula��o.

Municipios <- fread(paste0(InputFolder, "Municipios.csv"), 
                    sep = ";", dec = ",",
                    stringsAsFactors = FALSE)


SocioDemoEconomia <- fread(paste0(InputFolder, "SocioDemoEconomia.csv"), 
                           sep = ";", dec = ",",
                           stringsAsFactors = FALSE)

names(SocioDemoEconomia)
table(SocioDemoEconomia$SocioMunic_Ano)


# Evita problemas de classe de vari�vel.
Municipios$Munic_Id <- as.character(Municipios$Munic_Id)
SocioDemoEconomia$Munic_Id <- as.character(SocioDemoEconomia$Munic_Id)

Data <- SocioDemoEconomia %>% 
  left_join(Municipios, by = "Munic_Id") %>% 
  select(UF_Id, Munic_Id, SocioMunic_Ano, Munic_Nome, SocioMunic_Populacao) %>% 
  mutate(SocioMunic_Ano = as.integer(SocioMunic_Ano)) %>% 
  rename(year = SocioMunic_Ano) %>% 
  filter(year >= 2004 & year <= 2012)
  
# Checa dados
names(Data)
dim(Data)
head(Data)

# Compara dados Spada

table(Data$year)
table(Spada.Data$year)
head(Data)

names(Data)
names(Spada.Data)

# DFs <- list(Data, Spada.Data)
# Id_Vars <- list("Munic_Id" = "codeipea", "year" = "year")
# Compare_Vars <- list("SocioMunic_Populacao" = "pop", "Munic_Nome" = "Munic�pio")

ComparaBancos(DFs = list(Data, Spada.Data),
              Id_Vars = list("Munic_Id" = "codeipea", "year" = "year"),
              Compare_Vars = list("SocioMunic_Populacao" = "pop", "Munic_Nome" = "Munic�pio"))

# Limpa mem�ria
rm(Municipios, SocioDemoEconomia)


# Adiciona Vari�vel dependente.
MunicOp <- fread(paste0(InputFolder, "MunicOp.csv"), 
                 sep = ";", dec = ",",
                 stringsAsFactors = FALSE)

MunicOp <- MunicOp %>% 
  mutate(Munic_Id = as.character(Munic_Id)) %>% 
  mutate(MunicOp_Ano = as.integer(MunicOp_Ano)) %>% 
  rename(year = MunicOp_Ano)
  
names(MunicOp)
head(MunicOp)


Data.New <- Data %>% 
  left_join(MunicOp, by = c("Munic_Id", "year")) %>% 
  mutate(MunicOP_OP = ifelse(is.na(MunicOP_OP), 0, MunicOP_OP))


names(Data.New)
head(Data.New)
table(Data.New$MunicOP_OP)

Data <- Data.New

names(Data)
names(Spada.Data)

ComparaBancos(DFs = list(Data, Spada.Data),
              Id_Vars = list("Munic_Id" = "codeipea", "year" = "year"),
              Compare_Vars = list("MunicOP_OP" = "pb"))



rm(MunicOp, Data.New)


# Adiciona Munic�pios onde o PT ganhou antes de 2002
# Adiciona Munic�pios onde o PT ganhou depois de 2002


# Aten��o essa tabela � grande e pode demorar um pouco ser carregada!
CandidatoAno <- fread(paste0(InputFolder, "CandidatoAno.csv"), 
                      sep = ";", dec = ",",
                      stringsAsFactors = FALSE)



names(CandidatoAno)
head(CandidatoAno)
names(Data)

Prefeitos.PT <- CandidatoAno %>% 
  select(Munic_Id, CandAno_Ano, CandAno_Cargo, Partido_Id,
         CandAno_SituacaoElec) %>% 
  rename(year = CandAno_Ano) %>% 
  mutate(year = as.integer(year)) %>% 
  mutate(Munic_Id = as.character(Munic_Id)) %>%
  filter(CandAno_Cargo == "PREFEITO") %>% 
  filter(Partido_Id == 13) %>% 
  select(Munic_Id, year) %>% 
  mutate(PTAntes2002 = 1)


names(Prefeitos.PT)
dim(Prefeitos.PT)

PTAntes2002 <- Data %>% 
  select(Munic_Id, year) %>% 
  left_join(Prefeitos.PT, by = c("Munic_Id", "year")) %>% 
  filter(year < 2002) %>% 
  mutate(Prefeitos.PT = ifelse(is.na(Prefeitos.PT), 0, 1)) %>% 
  group_by(Munic_Id) %>% 
  mutate(PTAntes2002 = ifelse(sum(Prefeitos.PT) > 0, 1, 0)) %>% 
  ungroup() %>% 
  select(-Prefeitos.PT)


names(PTAntes2002)
head(PTAntes2002)
View(PTAntes2002)
table(PTAntes2002$PTAntes2002)

PTDepois2002 <- Data %>% 
  select(Munic_Id, year) %>% 
  left_join(Prefeitos.PT, by = c("Munic_Id", "year")) %>% 
  filter(year >= 2002) %>% 
  mutate(Prefeitos.PT = ifelse(is.na(Prefeitos.PT), 0, 1)) %>% 
  group_by(Munic_Id) %>% 
  mutate(PTDepois2002 = ifelse(sum(Prefeitos.PT) > 0, 1, 0)) %>% 
  ungroup() %>% 
  select(-Prefeitos.PT)


names(PTDepois2002)
head(PTDepois2002)
View(PTDepois2002)
table(PTDepois2002$PTDepois2002)


Data.New <- Data %>% 
  left_join(PTAntes2002, by = c("Munic_Id", "year")) %>% 
  left_join(PTDepois2002, by = c("Munic_Id", "year")) %>% 
  mutate(PTAntes2002 = ifelse(is.na(PTAntes2002), 0, PTAntes2002)) %>%
  mutate(PTDepois2002 = ifelse(is.na(PTDepois2002), 0, PTDepois2002))


names(Data.New)
head(Data.New)
table(Data.New$PTAntes2002)
table(Data.New$PTDepois2002)

Data <- Data.New


names(Data)
head(Data)


rm(Data.New, Prefeitos.PT, PTAntes2002, PTDepois2002)


# Adiciona Continuidade de governo.

names(CandidatoAno)

Continuedade.Pref <- CandidatoAno %>% 
  select(Munic_Id, CandAno_Ano, CandAno_Cargo, Partido_Id,
         CandAno_SituacaoElec, CandAno_Nome) %>% 
  filter(CandAno_Cargo == "PREFEITO") %>% 
  filter(CandAno_SituacaoElec == 1) %>% 
  rename(year = CandAno_Ano) %>% 
  mutate(year = as.integer(year)) %>% 
  mutate(Munic_Id = as.character(Munic_Id)) %>%
  arrange(Munic_Id, year) %>% 
  group_by(Munic_Id) %>% 
  mutate(Reeleito = ifelse(CandAno_Nome == dplyr::lag(CandAno_Nome), 1, 0)) %>% 
  ungroup() %>% 
  select(Munic_Id, year, Reeleito)

names(Continuedade.Pref)
head(Continuedade.Pref)
dim(Continuedade.Pref)
View(Continuedade.Pref)
table(Continuedade.Pref$year)
table(Continuedade.Pref$Reeleito, useNA = "always")


# Vulnerabilidade do prefeito (ratio of runner-up votes over mayor's party votes)

names(CandidatoAno)

Vulnerabilidade.Pref <- CandidatoAno %>%
  select(Munic_Id, CandAno_Ano, CandAno_Cargo, CandAno_QtVotos, CandAno_Turno) %>% 
  filter(CandAno_Cargo == "PREFEITO") %>% 
  filter(CandAno_Turno == 1) %>% 
  rename(year = CandAno_Ano) %>% 
  mutate(year = as.integer(year)) %>% 
  mutate(Munic_Id = as.character(Munic_Id)) %>%
  group_by(Munic_Id, year) %>% 
  arrange(desc(CandAno_QtVotos)) %>% 
  summarise(PrimeiroColocado = CandAno_QtVotos[1], 
            SegundoColocado = CandAno_QtVotos[2]) %>% 
  mutate(Vulnerabilidade.Pref = SegundoColocado / PrimeiroColocado)


names(Vulnerabilidade.Pref)
head(Vulnerabilidade.Pref)
View(Vulnerabilidade.Pref)


# Adiciona Controle do prefeito sobre a C�mara. (a dummy that identifies if the party of the 
# mayor holds the majority of seats).

names(CandidatoAno)



Bancadas.Vereador <- CandidatoAno %>%
  select(Munic_Id, CandAno_Ano, CandAno_Cargo, Partido_Id,
         CandAno_SituacaoElec) %>% 
  filter(CandAno_Cargo == "VEREADOR") %>% 
  filter(CandAno_SituacaoElec == 1) %>% 
  rename(year = CandAno_Ano) %>% 
  mutate(year = as.integer(year)) %>% 
  mutate(Munic_Id = as.character(Munic_Id)) %>%
  group_by(Munic_Id, year) %>% 
  summarise(NBancada = n())
  

head(Bancadas.Vereador, n = 10)

# Adiciona Tamanho da base do prefeito na c�mara (mayor's party shares of seats in the chamber)


rm(CandidatoAno)

# Adiciona de proximidade (retirar de Spada)

names(Spada.Data)

GeoData <- Spada.Data %>% 
  select(codeipea, year, peerproximity, peerproximity_weight) %>% 
  rename(Munic_Id = codeipea) %>% 
  mutate(Munic_Id = as.character(Munic_Id)) %>% 
  mutate(year = as.integer(year))

names(GeoData)

Data.New <- Data %>% 
  left_join(GeoData, by = c("Munic_Id", "year")) %>% 
  mutate(peerproximity = ifelse(is.na(peerproximity), 0, peerproximity)) %>% 
  mutate(peerproximity_weight = ifelse(is.na(peerproximity_weight), 0, peerproximity_weight)) 

names(Data.New)
head(Data.New)
table(Data.New$peerproximity)
table(Data.New$peerproximity_weight)

Data <- Data.New

rm(Data.New, GeoData)

# Adiciona a autonomia fiscal (receita tribut�ria sobre a recenta total).
# Adiciona Finalcial viability index (Receitas/Despesas)

MunicFinancas <- fread(paste0(InputFolder, "MunicFinancas.csv"), 
                       sep = ";", dec = ",",
                       stringsAsFactors = FALSE)

ContasPublicas <- fread(paste0(InputFolder, "ContasPublicas.csv"), 
                       sep = ";", dec = ",",
                       stringsAsFactors = FALSE)


names(MunicFinancas)
head(MunicFinancas)
names(ContasPublicas)

ContasPublicas$ContasPublica_Id <- as.character(ContasPublicas$ContasPublica_Id)
MunicFinancas$ContasPublica_Id <- as.character(MunicFinancas$ContasPublica_Id)


Dados.Financas <- ContasPublicas %>% 
  select(ContasPublica_Id, ContasPublica_Nome) %>% 
  right_join(MunicFinancas, by = "ContasPublica_Id") %>% 
  select(Munic_Id, MunicFinancas_Ano, ContasPublica_Nome, MunicFinancas_ContaValor) %>% 
  filter(Munic_Id %in% Data$Munic_Id) %>% 
  rename(year = MunicFinancas_Ano) %>% 
  mutate(Munic_Id = as.character(Munic_Id)) %>% 
  mutate(year = as.integer(year)) %>% 
  spread(ContasPublica_Nome, MunicFinancas_ContaValor) %>% 
  group_by(Munic_Id, year) %>% 
  summarise(RecTotal = sum(RecCor) + sum(RecCap) - sum(DeducCor, na.rm = TRUE),
            RecTributaria = sum(RecTributaria),
            DespTotal = sum(DesCor) + sum(DespCap)) %>% 
  mutate(AutonomiaFiscal = RecTributaria / RecTotal) %>% 
  mutate(ViabilidadeFiscal = DespTotal / RecTotal)
  

names(Dados.Financas)
dim(Dados.Financas)
head(Dados.Financas)

Data.New <- Data %>% 
  left_join(Dados.Financas, by = c("Munic_Id", "year"))

names(Data.New)
dim(Data.New)
head(Data.New)
View(Data.New)

Data <- Data.New

rm(Data.New, Dados.Financas, ContasPublicas)
rm(MunicFinancas)


# Adiciona Dummies:
## 1996-2000
## 2001-2004
## 2005-2008
## 2009-2012




