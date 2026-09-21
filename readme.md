# Instalação — Autenticação LDAP no Chatwoot Community

Este documento descreve o processo de instalação da autenticação LDAP no **Chatwoot Community Edition**.

> [!IMPORTANT]
> Este projeto altera o fluxo de autenticação do Chatwoot. Faça backup da instalação e do banco de dados antes de aplicar qualquer alteração em produção.

> [!NOTE]
> Os exemplos abaixo consideram uma instalação padrão do Chatwoot em:
>
> ```text
> /home/chatwoot/chatwoot
> ```
>
> Caso sua instalação esteja em outro diretório, ajuste os caminhos conforme necessário.

---

## 1. Verificar a dependência `net-ldap`

Primeiro, verifique se a biblioteca `net-ldap` já está disponível na instalação do Chatwoot:

```bash
sudo -u chatwoot -H bash -lc '
cd /home/chatwoot/chatwoot
bundle info net-ldap
'
```

Se o comando retornar as informações da gem, você pode seguir para a próxima etapa.

### Caso a gem não esteja instalada

Entre no diretório do Chatwoot:

```bash
cd /home/chatwoot/chatwoot
```

Adicione a dependência ao `Gemfile`:

```bash
echo "gem 'net-ldap', '~> 0.20'" >> Gemfile
```

Depois instale as dependências:

```bash
sudo -u chatwoot -H bash -lc '
cd /home/chatwoot/chatwoot
bundle install
'
```

Confirme novamente:

```bash
sudo -u chatwoot -H bash -lc '
cd /home/chatwoot/chatwoot
bundle info net-ldap
'
```

---

## 2. Criar o serviço de autenticação LDAP

Crie o arquivo responsável por realizar a autenticação no servidor LDAP:

```bash
nano /home/chatwoot/chatwoot/app/services/ldap_authentication_service.rb
```

Copie para esse arquivo o conteúdo correspondente disponível neste repositório:

```text
app/services/ldap_authentication_service.rb
```

Salve utilizando:

```text
CTRL + O
ENTER
CTRL + X
```

---

## 3. Criar o serviço de provisionamento de usuários

Agora crie o serviço responsável pelo provisionamento dos usuários LDAP no Chatwoot:

```bash
nano /home/chatwoot/chatwoot/app/services/ldap_user_provisioning_service.rb
```

Copie o conteúdo correspondente disponível neste repositório:

```text
app/services/ldap_user_provisioning_service.rb
```

Esse serviço é responsável por tratar o usuário autenticado pelo LDAP e integrá-lo ao sistema de usuários do Chatwoot.

---

## 4. Aplicar o fluxo de login exclusivo pelo LDAP

Crie o Concern responsável por interceptar o processo de autenticação do Chatwoot:

```bash
nano /home/chatwoot/chatwoot/app/controllers/concerns/ldap_only_login_patch.rb
```

Copie o conteúdo disponível neste repositório:

```text
app/controllers/concerns/ldap_only_login_patch.rb
```

Esse patch altera apenas o processo de autenticação.

As funções, perfis e permissões continuam sendo controladas pelo próprio Chatwoot.

---

## 5. Carregar o patch na inicialização do Chatwoot

Crie o initializer:

```bash
nano /home/chatwoot/chatwoot/config/initializers/ldap_only_login.rb
```

Copie o conteúdo correspondente:

```text
config/initializers/ldap_only_login.rb
```

Esse arquivo garante que o patch LDAP seja carregado quando a aplicação Rails iniciar.

---

## 6. Validar a sintaxe dos arquivos Ruby

Antes de reiniciar o Chatwoot, valide todos os arquivos alterados.

Execute:

```bash
cd /home/chatwoot/chatwoot

ruby -c app/services/ldap_authentication_service.rb &&
ruby -c app/services/ldap_user_provisioning_service.rb &&
ruby -c app/controllers/concerns/ldap_only_login_patch.rb &&
ruby -c config/initializers/ldap_only_login.rb
```

O resultado esperado para cada arquivo é:

```text
Syntax OK
```

Exemplo:

```text
Syntax OK
Syntax OK
Syntax OK
Syntax OK
```

> [!WARNING]
> Caso qualquer arquivo apresente erro de sintaxe, não reinicie o Chatwoot até corrigir o problema.

---

## 7. Validar se o patch foi carregado

Agora confirme se o `LdapOnlyLoginPatch` foi aplicado corretamente ao controller de sessão do Chatwoot.

Execute:

```bash
sudo -u chatwoot -H bash -lc '
cd /home/chatwoot/chatwoot
RAILS_ENV=production bundle exec rails runner \
"puts \"LDAP patch: #{DeviseOverrides::SessionsController < LdapOnlyLoginPatch}\""
'
```

O resultado esperado é:

```text
LDAP patch: true
```

Se retornar:

```text
LDAP patch: false
```

ou apresentar alguma exceção, verifique:

```text
config/initializers/ldap_only_login.rb
```

e:

```text
app/controllers/concerns/ldap_only_login_patch.rb
```

---

## 8. Reiniciar o Chatwoot

Depois que todas as validações forem concluídas com sucesso, reinicie o serviço web do Chatwoot:

```bash
systemctl restart chatwoot-web.1.service
```

Confirme se o serviço voltou corretamente:

```bash
systemctl status chatwoot-web.1.service --no-pager
```

O serviço deve aparecer como:

```text
Active: active (running)
```

---

## 9. Acompanhar os logs

Abra os logs do serviço:

```bash
journalctl -u chatwoot-web.1.service -f
```

Com o log aberto, acesse o Chatwoot pelo navegador e realize um teste de autenticação.

Durante o teste, acompanhe as mensagens exibidas no terminal.

Para sair do acompanhamento dos logs:

```text
CTRL + C
```

---

# Fluxo de autenticação

Depois da implementação, o fluxo esperado é:

```text
Usuário
   │
   ▼
Tela de Login
   │
   ▼
Chatwoot
   │
   ▼
LDAP / Active Directory
   │
   ├── Credenciais inválidas
   │
   └──────► Login negado
   │
   └── Credenciais válidas
            │
            ▼
       Usuário existe?
          │      │
         SIM    NÃO
          │      │
          │      ▼
          │   Provisionar
          │    usuário
          │      │
          └──┬───┘
             │
             ▼
       Login no Chatwoot
             │
             ▼
    Permissões continuam
   controladas pelo Chatwoot
```

---

# Validação recomendada

Após a instalação, valide pelo menos os seguintes cenários:

* Usuário LDAP válido consegue autenticar.
* Usuário com senha LDAP incorreta não consegue autenticar.
* Usuário inexistente no LDAP não consegue autenticar.
* Usuário já existente no Chatwoot mantém suas permissões.
* Usuário provisionado pelo LDAP recebe apenas as permissões esperadas.
* Administrador continua administrador após autenticação.
* Agente continua agente após autenticação.
* Reiniciar o Chatwoot não remove o patch.
* Erros de conexão LDAP são registrados corretamente nos logs.

---

# Verificação rápida

Você pode utilizar os comandos abaixo para verificar rapidamente o estado da implementação.

### Verificar `net-ldap`

```bash
sudo -u chatwoot -H bash -lc '
cd /home/chatwoot/chatwoot
bundle info net-ldap
'
```

### Validar sintaxe

```bash
cd /home/chatwoot/chatwoot

ruby -c app/services/ldap_authentication_service.rb &&
ruby -c app/services/ldap_user_provisioning_service.rb &&
ruby -c app/controllers/concerns/ldap_only_login_patch.rb &&
ruby -c config/initializers/ldap_only_login.rb
```

### Validar carregamento do patch

```bash
sudo -u chatwoot -H bash -lc '
cd /home/chatwoot/chatwoot
RAILS_ENV=production bundle exec rails runner \
"puts \"LDAP patch: #{DeviseOverrides::SessionsController < LdapOnlyLoginPatch}\""
'
```

### Verificar o serviço

```bash
systemctl status chatwoot-web.1.service --no-pager
```

### Acompanhar logs

```bash
journalctl -u chatwoot-web.1.service -f
```

---

# SuperAdmin

> [!CAUTION]
> O acesso da conta **SuperAdmin** utilizando LDAP ainda não foi validado.

Até que esse cenário seja devidamente testado, recomenda-se manter um método de recuperação administrativa disponível.

Não dependa exclusivamente do LDAP para acesso administrativo até concluir os testes com o SuperAdmin.

---

# Recuperação em caso de problema

Caso o Chatwoot não inicialize depois das alterações, acompanhe os logs:

```bash
journalctl -u chatwoot-web.1.service -n 200 --no-pager
```

Também é possível verificar erros diretamente pelo Rails:

```bash
sudo -u chatwoot -H bash -lc '
cd /home/chatwoot/chatwoot
RAILS_ENV=production bundle exec rails runner "puts :ok"
'
```

Se necessário, restaure os arquivos originais e reinicie:

```bash
systemctl restart chatwoot-web.1.service
```

---

# Observações

Esta implementação tem como objetivo adicionar autenticação LDAP ao Chatwoot Community Edition.

Ela não tem como objetivo:

* Alterar as permissões internas do Chatwoot.
* Conceder privilégios administrativos automaticamente.
* Modificar o sistema de autorização do Chatwoot.
* Desbloquear funcionalidades Enterprise.
* Modificar verificações de licença.
* Remover controles de acesso existentes.

O LDAP é responsável pela **autenticação**.

O Chatwoot continua responsável pela **autorização e permissões**.
