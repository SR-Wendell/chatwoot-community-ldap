================== INSTALAÇÃO =============

1. Valide se o net-ldap já existe no Host do seu Chatwoot

sudo -u chatwoot -H bash -lc '
cd /home/chatwoot/chatwoot
bundle info net-ldap
'

-CASO DE ERRO EXECUTE

echo "gem 'net-ldap', '~> 0.20'" >> Gemfile

E 

sudo -u chatwoot -H bash -lc '
cd /home/chatwoot/chatwoot
bundle install
'

2. AGORA CRIE O SERVIÇO DO LDAP

nano /home/chatwoot/chatwoot/app/services/ldap_authentication_service.rb ( Está no codigo)

3. CRIE AGORA O PROVISONAMENTO DOS USUARIOS

nano app/services/ldap_user_provisioning_service.rb ( Está no código)

4. FAÇA O CHATWOOT APENAS FAZER LOGIN PELO LDAP

nano app/controllers/concerns/ldap_only_login_patch.rb

5. CARREGUE O PACTH
   
nano config/initializers/ldap_only_login.rb

6. AGORA VAMOS VALIDAR OS ARQUIVOS QUE EDITAMOS

ruby -c app/services/ldap_authentication_service.rb
ruby -c app/services/ldap_user_provisioning_service.rb
ruby -c app/controllers/concerns/ldap_only_login_patch.rb
ruby -c config/initializers/ldap_only_login.rb

--O RESULTADO TEM QUE SER 

SYNTAX OK

7. DEPOIS VALIDE O LDAP

sudo -u chatwoot -H bash -lc '
cd /home/chatwoot/chatwoot
RAILS_ENV=production bundle exec rails runner "
puts \"LDAP patch: #{DeviseOverrides::SessionsController < LdapOnlyLoginPatch}\"
"
'

--RESULTADO ESPERADO É

LDAP patch: true

8.AGORA REINICIE O SERVIÇO DO CHATWOOT

systemctl restart chatwoot-web.1.service

9.RODA O COMANDO DE VALIDAÇÃO DE LOGS E ACESSO NO WEB E ACOMPANHE O PROCESSO

journalctl -u chatwoot-web.1.service -f


========= APENAS A CONTA SUPERADMIN NÃO VALIDEI AINDA O ACESSO VIA LDAP ============
