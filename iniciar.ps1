param([switch]$Recompilar)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$pythonMentorly = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $pythonMentorly)) {
    python -m venv .venv --without-pip
    if ($LASTEXITCODE -ne 0) { throw 'Não foi possível criar o ambiente Python.' }
}
# O pip do Python principal consegue preparar o ambiente isolado sem ativacao.
python -m pip --python .venv install -r backend/requirements.txt
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível instalar as dependências.' }
if ($Recompilar) { & $pythonMentorly iniciar.py --recompilar }
else { & $pythonMentorly iniciar.py }
if ($LASTEXITCODE -ne 0) { throw 'O Mentorly não iniciou. Confira a mensagem acima.' }
