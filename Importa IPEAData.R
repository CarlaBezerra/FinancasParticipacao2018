

# Script para Importar dados sociais, econ�micos e demogr�ficos 
# dos munic�pios brasileiros

# Criado por Murilo Junqueira

# Data cria��o: 2018-03-15
# Ultima modifica��o: 2018-03-15

# Documenta��o do pacote de extra��o dos dados do IPEA Data:
# https://cran.r-project.org/web/packages/ecoseries/index.html

# Site do IPEA Data:
# http://www.ipeadata.gov.br/Default.aspx


################## Prepara �rea de trabalho ##################

#clean memory
rm(list=ls(all=TRUE))
gc()

# instala o pacote de extra��o dos dados, se necess�rio
# install.packages("ecoseries") 
library(ecoseries) # Brazilians Economic Statistics data
library(tidyverse)
library(data.table)
library(readxl)


# Os diret�rios de inser��o dos dados Brutos (InputFolder), destino dos 
# dados (OutputFolder) e localiza��o dos scripts (ScriptFolder). Atualize se necess�rio!
InputFolder <- "C:/Users/mjunqueira/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Dados/Dados Brutos/IPEAData/"
OutputFolder <- "C:/Users/mjunqueira/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Dados/BD csv/"
ScriptFolder <- "C:/Users/mjunqueira/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Scripts R/"



################## Importa dados do IPEA Data ##################

# Os n�meros das s�ries n�o est�o descritas em nenhuma documenta��o,
# � necess�rio observar caso a caso no site do IPEA Data.

# N�mero das s�ries de dados:
## popula��o - 1776285356

# Dados populacionais
# PopMunic <- series_ipeadata(1776285356, periodicity = c("Y"))


FullPath <- paste0(InputFolder, "PopulacaoMunic_1992-2017.xls")
FullPath.Censo <- paste0(InputFolder, "PopulacaoMunic_Censo1991-2010.csv")
PopMunic <- read_excel(FullPath, sheet = "S�ries")

PopMunic.Censo <- fread(FullPath.Censo, skip = 1, header = TRUE,
                        sep = ";", dec = ",", stringsAsFactors = FALSE)

names(PopMunic.Censo)
names(PopMunic)

PopMunic.Censo <- PopMunic.Censo %>% 
  select(-Sigla, -Munic�pio) %>% 
  rename(Codigo = C�digo)

firstCol <- names(PopMunic)[4]
lasteCol <- names(PopMunic.Censo)[ncol(PopMunic.Censo)]

PopMunic$Codigo <- as.character(PopMunic$Codigo)
PopMunic.Censo$Codigo <- as.character(PopMunic.Censo$Codigo)

PopMunic.tidy <- PopMunic %>%
  select(-Sigla, -matches("Munic�pio")) %>%
  left_join(PopMunic.Censo, by = "Codigo") %>% 
  rename(Munic_Id = Codigo) %>% 
  select(-matches(".y")) %>% 
  rename("2000" = "2000.x") %>% 
  gather(SocioMunic_Ano, SocioMunic_Populacao, firstCol:lasteCol) %>% 
  mutate(SocioMunic_Ano = as.integer(SocioMunic_Ano)) %>% 
  mutate(SocioMunic_Populacao = as.integer(SocioMunic_Populacao)) %>% 
  filter(!is.na(SocioMunic_Ano))

names(PopMunic.tidy)

table(PopMunic.tidy$SocioMunic_Ano)

View(PopMunic.tidy)

rm(firstCol, lasteCol, FullPath)
rm(PopMunic, PopMunic.Censo)


FullPath <- paste0(InputFolder, "PIBMunic_1996-2017.xls")
PIBMunic <- read_excel(FullPath, sheet = "S�ries")

names(PIBMunic)

firstCol <- names(PIBMunic)[4]
lasteCol <- names(PIBMunic)[ncol(PIBMunic)]

PIBMunic.tidy <- PIBMunic %>%
  select(-Sigla, -matches("Munic�pio")) %>%
  rename(Munic_Id = Codigo) %>% 
  gather(SocioMunic_Ano, SocioMunic_PIB, firstCol:lasteCol) %>% 
  mutate(SocioMunic_Ano = as.integer(SocioMunic_Ano)) %>% 
  mutate(SocioMunic_PIB = as.numeric(SocioMunic_PIB))


names(PIBMunic.tidy)
head(PIBMunic.tidy)

SocioMunic <- left_join(PopMunic.tidy, PIBMunic.tidy, by = c("Munic_Id", "SocioMunic_Ano"))

nrow(PopMunic.tidy)
nrow(PIBMunic.tidy)
nrow(SocioMunic)

rm(firstCol, lasteCol, FullPath)
rm(PIBMunic)
rm(PIBMunic.tidy, PopMunic.tidy)

Output.pathFile <- paste0(OutputFolder, "SocioDemoEconomia.csv")

names(SocioMunic)
head(SocioMunic)

table(SocioMunic$SocioMunic_Ano[!is.na(SocioMunic$SocioMunic_PIB)])

# Grava o arquivo  
write.table(SocioMunic, file = Output.pathFile, 
            sep = ";", dec = ",", row.names=FALSE)


rm(Output.pathFile)
rm(SocioMunic)






