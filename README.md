# Gasto Azul — Starter v0.1

Protótipo Android/Flutter para controle pessoal de gastos com:

- visual branco + azul em Material 3;
- saldo total e saldo por conta;
- Banco do Brasil e PicPay;
- lançamento manual de receitas e gastos;
- histórico de movimentações;
- leitura de notificações bancárias no Android;
- interpretação inicial de Pix recebido/enviado, compras e pagamentos;
- confirmação antes de alterar o saldo;
- cache de notificações quando o app estiver fechado.

## 1. Criar a base Flutter

No terminal:

```bash
flutter create --org com.gastoazul --project-name gasto_azul gasto_azul
cd gasto_azul
```

Depois substitua os arquivos do projeto pelos arquivos equivalentes desta pasta.

Os Kotlin ficam em:

```text
android/app/src/main/kotlin/com/gastoazul/gasto_azul/
```

## 2. Rodar

Conecte um Android com depuração USB ou abra um emulador:

```bash
flutter pub get
flutter run
```

## 3. Ativar leitura das notificações

Dentro do app, toque no botão de sino ou em **Configurar notificações**. O Android abrirá a tela de acesso às notificações. Autorize **Gasto Azul**.

O listener nativo recebe apenas notificações que parecem vir de PicPay/Banco do Brasil e que contenham sinais financeiros como Pix, R$, compra ou pagamento.

## 4. Como testar sem movimentar dinheiro

A tela e os lançamentos manuais funcionam sem a permissão. Para validar o parser em desenvolvimento, altere temporariamente o método `looksLikeSupportedBank` no Kotlin ou crie testes Dart com textos fictícios.

Exemplos esperados pelo parser:

- `PicPay — Pix feito no valor de R$ 50,00` → gasto de R$ 50,00 no PicPay.
- `PicPay — Você recebeu um Pix de R$ 100,00` → receita de R$ 100,00 no PicPay.
- `Banco do Brasil — Compra realizada de R$ 35,90` → gasto no Banco do Brasil.

## Limitações intencionais desta v0.1

- Os saldos e movimentos da interface ainda ficam apenas em memória enquanto o app está aberto.
- O parser precisa ser ajustado com exemplos reais (sem dados pessoais) das notificações do BB e PicPay.
- Não há login, nuvem, Supabase, Open Finance ou categorização inteligente ainda.
- O app pede confirmação antes de lançar notificações; isso reduz erros do parser no começo.

## Próxima etapa recomendada — v0.2

1. persistência local criptografada;
2. tela de onboarding para saldo inicial;
3. categorias e orçamento mensal;
4. deduplicação de notificações;
5. regras específicas para textos reais do BB/PicPay;
6. gráficos mensais;
7. opção de lançamento automático apenas para regras com alta confiança.

## Gerar APK automaticamente pelo GitHub Actions

Este pacote inclui `.github/workflows/build-apk.yml`.

O workflow instala Flutter 3.44.0, gera o esqueleto Android completo, aplica a integração nativa do leitor de notificações e compila `GastoAzul-v0.1.apk` em modo release.

O APK resultante aparece como artifact chamado `GastoAzul-APK` na execução do workflow.

> Observação: a versão release gerada a partir do template Flutter usa a configuração de assinatura de desenvolvimento do projeto. Ela é adequada para testes pessoais e instalação direta. Para publicar na Google Play, configure uma chave de assinatura própria e gere preferencialmente um App Bundle (`.aab`).
