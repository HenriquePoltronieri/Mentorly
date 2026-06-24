# Guia de Comandos - Mentorly

Este documento reúne os principais comandos utilizados durante o desenvolvimento do projeto Mentorly.

---

# GitHub e Git

## Configurar nome de usuário

```bash
git config --global user.name "Seu Nome"
```

## Configurar e-mail

```bash
git config --global user.email "seuemail@email.com"
```

## Verificar configurações

```bash
git config --list
```

## Fazer login no GitHub

Após instalar o GitHub CLI:

```bash
gh auth login
```

Siga as instruções exibidas pelo terminal.

## Verificar autenticação

```bash
gh auth status
```

---

# Git

## Clonar o repositório

```bash
git clone https://github.com/SEU-USUARIO/mentorly.git
```

## Entrar na pasta do projeto

```bash
cd mentorly
```

## Verificar status

```bash
git status
```

## Baixar atualizações do repositório

```bash
git pull
```

## Adicionar alterações

```bash
git add .
```

## Criar commit

```bash
git commit -m "descrição da alteração"
```

## Enviar alterações para o GitHub

```bash
git push
```

## Criar uma nova branch

```bash
git checkout -b nome-da-branch
```

## Trocar de branch

```bash
git checkout nome-da-branch
```

## Ver todas as branches

```bash
git branch
```

## Atualizar lista de branches remotas

```bash
git fetch
```

## Mesclar alterações

```bash
git merge nome-da-branch
```

---

# Flutter

## Verificar instalação

```bash
flutter doctor
```

## Instalar dependências

```bash
flutter pub get
```

## Executar aplicação

```bash
flutter run
```

## Executar em dispositivo específico

```bash
flutter run -d <device-id>
```

## Gerar APK

```bash
flutter build apk
```

## Limpar cache

```bash
flutter clean
```

## Atualizar dependências

```bash
flutter pub upgrade
```

## Ver dispositivos conectados

```bash
flutter devices
```

---

# Python / Flask

## Criar ambiente virtual

```bash
python -m venv venv
```

## Ativar ambiente virtual (Windows)

```bash
venv\Scripts\activate
```

## Ativar ambiente virtual (Linux/Mac)

```bash
source venv/bin/activate
```

## Instalar dependências

```bash
pip install -r requirements.txt
```

## Executar servidor Flask

```bash
python app.py
```

## Salvar dependências

```bash
pip freeze > requirements.txt
```

## Atualizar pip

```bash
python -m pip install --upgrade pip
```

---

# MySQL

## Acessar MySQL

```bash
mysql -u root -p
```

## Criar banco de dados

```sql
CREATE DATABASE mentorly;
```

## Selecionar banco

```sql
USE mentorly;
```

## Listar bancos

```sql
SHOW DATABASES;
```

## Listar tabelas

```sql
SHOW TABLES;
```

## Exibir estrutura de uma tabela

```sql
DESCRIBE nome_da_tabela;
```

---

# Estrutura Recomendada do Projeto

```text
mentorly/
│
├── frontend/
│   └── Projeto Flutter
│
├── backend/
│   └── API Flask
│
├── database/
│   └── Scripts SQL
│
├── docs/
│   └── Documentação
│
├── README.md
├── GUIA.md
└── .gitignore
```

---

# Fluxo de Trabalho da Equipe

## 1. Atualizar o projeto

```bash
git pull
```

## 2. Criar uma branch para sua tarefa

```bash
git checkout -b minha-feature
```

## 3. Fazer as alterações necessárias

## 4. Verificar alterações

```bash
git status
```

## 5. Adicionar arquivos

```bash
git add .
```

## 6. Criar commit

```bash
git commit -m "feat: adiciona nova funcionalidade"
```

## 7. Enviar para o GitHub

```bash
git push origin minha-feature
```

---

# Convenção de Commits

## Nova funcionalidade

```text
feat: adiciona cadastro de professores
```

## Correção de bugs

```text
fix: corrige erro no login
```

## Documentação

```text
docs: atualiza README
```

## Refatoração

```text
refactor: reorganiza estrutura do backend
```

## Interface

```text
style: melhora layout da tela inicial
```

## Testes

```text
test: adiciona testes do módulo de autenticação
```

---

# Comandos Mais Utilizados no Dia a Dia

```bash
git pull
git status
git add .
git commit -m "mensagem"
git push

flutter pub get
flutter run

python app.py
```