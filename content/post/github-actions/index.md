+++
date = "2021-09-12"
title = "Github Actions"
draft = false
tags = ["Github", "Github Actions", "Continuous Integration"]
toc = true
+++

## O que é isso?

O Github Actions é primariamente uma ferramenta para implementar Continuous
Integration, ou seja, automatizar a execução de ferramentas ou processos que
ajudam a garantir a qualidade do código, seja teste unitários, análises de
código estática, analises de segurança, simplesmente compilar/"buildar" o
projeto.

Além disso também podemos implementar fluxos de Continuous Delivery, fazendo o
deploy ou bundle do projeto de forma automática sempre que um evento acontece,
seja o `push` para uma branch, ou algum outro evento do Github.

A grande maioria das ferramentas de CI permite fazer esses tipos de
controles/processos, mas o interessante do Github Actions é que ele esta integrado
com o sistema de eventos (webhooks) e com a API do Github, então quando você
quer usar funcionalidades do Github com os [commit status][],
[deployment status][], [checks/annotations][annotations] o processo é bem simples.

## Como temos usado o Github Actions/CI em geral

Para a maioria dos projetos da [Coderockr][] nós sempre adicionamos algumas
ferramentas para CI, que são executadas em todos os PRs e a maioria no `push`
para branchs "principais" (`main`, `develop`, `release`, etc).

Essas ferramentas são fazem lint, analise estática e testes unitários, todas
elas são "scriptáveis" e configuráveis, então podemos simplesmente com um shell
script simples podemos executar elas, capturar os arquivos com problema (as
vezes detalhando a linha específica) e notificar o desenvolvedor sobre os
problemas e bloquear o merge/deploy baseado nelas.

## Show me the code

Mas beleza, nós temos as ferramentas, como integrar elas no Github Actions?
Para isso temos de criar um `workflow`, que é o termo que o Github usa para
representar uma sequencia de etapas que é executada em resposta a um evento no
repositório ou API ([voltamos nisso depois][dispatch]).

:bulb: Todos os exemplos que vou mostrar podem ser vistos nesse repositório:
: [lucassabreu/github-actions-examples][]

### Workflow simples

Para criar o `workflow` basta fazer o commit de um arquivo `yaml` dentro da pasta
`.github/workflows`, e automaticamente o Github irá utilizar ele assim que o
evento que você definiu acontecer com a branch que estiver (alguns eventos só
vão funcionar se o `workflow` estiver na branch default).

Um exemplo simples que temos em alguns projetos é esse:

```yaml {linenos=table}
name: "PHPUnit"
on:
  pull_request:
  push:
    branches: [main]

jobs:
  php-tests:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: 8.0
          tools: composer:v2

      - name: Install dependencies
        run: composer install --prefer-dist

      - name: Execute Unit Tests
        run: php vendor/bin/phpunit
```
<p class="code-legend">.github/workflows/phpunit.yaml</p>

Esse é o tipo mais simples de `workflow` que pode ser feito no Github Actions,
apenas executa a cada push para a `main` e em todos os `pull requests`, e a
única saída gerada é o "commit status".

![commit status](phpunit-basic-checks.png#class=big "commit status gerados pelo workflow")

Mas com isso já possível bloquear `pull requests` que não atendem a qualidade
esperada, ou que quebrem algo no caso do PHPUnit; para todos os
desenvolvedores do projeto o acesso a porquê o commit não passou esta a um
click.

![check details](./github-actions-check-details.png#class=big "logs do phpunit no github actions")

### Lints/Analise Estática com annotations

Mas esse é só o básico podemos fazer algumas coisas mais avançadas com o Github
Actions e a integração "auto-mágica" com a API do Github.

Uma integração que precisava de um setup grande para fazer, mas que era muito boa
para auxiliar no revisão automática são os [annotations][]. Com eles podemos
criar "comentários" diretamente nos arquivos do PR/repositório de forma
automatizada, marcando inclusive qual a linha que tem o problema e qual o
problema daquela linha.

![phpstan github annotations](./phpstan-github-annotation.png#class=big "exemplo de annotations")

A utilidade disso é que agora quando o time for revisar o PR podemos focar no
design da solução e na regra de negócio que esta sendo implementada, no lugar de
revisar se o fonte possui problemas estruturais ou erros de
compilação/interpretação que possam acontecer.

Isso é claro depende do ferramental que a linguagem que você esta trabalhando
oferece, no caso do PHP quase todos os nossos projetos vão incluir o
[PHPStan][] (ou [Phan][]), [PHPMD][], [PHPCS][] e [PHP CS Fixer][] para
padronizar e analisar o código.

O exemplo da imagem anterior é feita com o seguinte `workflow`:

```yaml {linenos=table}
name: "PHPStan"
on:
  pull_request:
  push:
    branches: [main]

jobs:
  php-stan:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    env:
      COMPOSER_NO_INTERACTION: 1

    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: 8.0
          tools: composer:v2

      - name: Install dependencies
        run: composer install --prefer-dist

      - name: Execute PHPStan
        run: php vendor/bin/phpstan analyse src --level 8 --error-format=github
```
<p class="code-legend">exemplo de workflow com phpstan</p>

O mesmo é basicamente igual ao `workflow` criado para o PHPUnit antes, apenas
chamando o PHPStan dessa vez, e com isso ele já gera as `annotations`, isso
porque o Actions tem um conceito de "[workflow message commands][log-commands]".

Ele interpreta a saída do `workflow` e se a linha repeitar um dos formatos
abaixo, ele destaca essa informação.

```
::notice file={name},line={line},endLine={endLine},title={title}::{message}
::warning file={name},line={line},endLine={endLine},title={title}::{message}
::error file={name},line={line},endLine={endLine},title={title}::{message}
```

Quando o Actios identifica um desses formatos no output do `workflow` ele
automaticamente cria um `annotation` com o mesmo "nível" no `pull request` (se
existir um para a execução).

Então se eu criar um `step` como o abaixo:

```yaml {linenos=table,linenostart=18}
    - name: Fake
      run: |
        echo ::notice \
          file=$PWD/src/Hugger/Friendly.php,line=1,col=0::this is a notice
        echo ::warning \
          file=$PWD/src/Hugger/Friendly.php,line=1,col=0::this is a warning
        echo ::error \
          file=$PWD/src/Hugger/Friendly.php,line=1,col=0::this is a error

```

Vai gerar uma nova `annotation`:

![fake annotation](./fake-annotations.png#class=big)


Isso mostra quão fácil é integrar com essa funcionalidade do Github Actions,
várias ferramentas tem formatos de saída prontos para integrar com ele, e as
que não tem, bem estão a um [`sed`][sed] de distância.

## Integrações e "Actions"

Para a maioria das ferramentas, principalmente para as que pode/devem ser
executadas como parte do `pre-commit` usar o `step.run` é a melhor forma,
fácil de entender e inclusive já mostra como executar localmente assim o
desenvolvedor não precisa fazer o push para ver os resultados, ele pode apenas
rodar o `php vendor/bin/phpunit` no terminal antes de fazer o commit e feito.

Mas existem algumas etapas que podemos adicionar no `workflow` que não precisam
(talvez não devam) ser executadas localmente, por exemplo: deploys, cache de
arquivos, relatórios de cobertura, integrações com serviços externos, setup de
ferramentas para usar, etc.

Um exemplo simples é uma etapa para enviar o relatório de cobertura para o
[Codecov][]:

```yaml {linenos=table,hl_lines=["4-8"],linenostart=35}
      - name: Execute Unit Tests
        run: phpdbg -qrr vendor/bin/phpunit --coverage-clover=clover.xml

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v2
        with:
          files: ./clover.xml
```

A etapa `Upload coverage to Codecov` usa uma `action` chamada
[`codecov/codecov-action`][codecov-action], `actions` são o que dão o nome para a
plataforma, e são plugins que podem ser adicionados aos `workflows` que
resolvem algum problema específico, que podem ser os problemas que listei antes
ou "receitas prontas" para alguma ferramenta.

Diferente dos exemplos anteriores não passamos um script para ser executado na
etapa, mas sim qual o nome da `action` com o `uses` e (dependendo da `action`)
parâmetros complementares que ela possa receber.

O Github tem um marketplace para eles que você pode usar tanto para publicar os
seus próprios, quanto para procurar soluções prontas (por mais que o Google
tenha sido melhor para pesquisar, mas a pagina no marketplace ajuda o Google
pelo menos).

![marketplace](./github-marketplace.png#class=big "marketplace com alguns actions para php")

E podemos encontrar todo tipo de `action` pronta para ser adicionada aos
`workflows`, no meu blog eu não precisei escrever lógica para instalar o `hugo`
ou para "buildar" e fazer push dele para a branch `gh-pages`, isso tudo é feito
por `actions` que outras pessoas escreveram.

```yml {linenos=table,hl_lines=["17-20","25-29"]}
name: GH Pages
on:
  push:
    branches:
      - main

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout 🛎️
        uses: actions/checkout@v2.3.1
        with:
          submodules: true
          fetch-depth: 0

      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v2
        with:
          hugo-version: "0.87.0"

      - name: Build
        run: hugo -v --minify -b http://www.lucassabreu.net.br

      - name: Deploy 🚀
        uses: JamesIves/github-pages-deploy-action@4.1.5
        with:
          branch: gh-pages
          folder: public
```
<p class="code-legend">.github/workflows/gh-pages.yaml</p>

Existe uma grande variedade desses tipos de `actions` que fazem o setup para
uma ferramenta, ou que interagem com o Github ou outros serviços de forma
simplificada.

### Docker Steps

Nós usamos o Docker para o desenvolvimento local e em produção para a maioria
dos projetos para manter os ambientes o mais próximos possível. E no [Drone
CI][] e [Buildkite][] usamos as mesmas imagens (ou bem próximas) para executar
as ferramentas de analise estática e testes unitários, porque se estamos usando
uma imagem customizada é provável que eles falhem por não ter a referencia a
alguma função ou classe.

Nesse sentido no lugar de usar uma `action` para instalar a linguagem e ainda
adicionar extensões ou customizações do ambiente, por mais que possível, acaba
sendo um trabalho duplicado, e sempre temos de lembrar de atualizar a imagem
base e o `workflow` toda vez, então quando isso acontece nós usamos imagens do
Docker como etapas para rodar as operações.

Usando uma imagem do Docker no nível do `runs-on` adicionamos qual o contêiner
a ser usado:

```diff
name: "PHPUnit (with Docker)"
on:
  pull_request:
  push:
    branches: [main]

jobs:
  php-tests:
    runs-on: ubuntu-latest
+    container:
+      image: ghcr.io/lucassabreu/php-with-exts-example:main
+      options: --user root

    steps:
      - name: Checkout code
        uses: actions/checkout@v2

-      - name: Setup PHP
-        uses: shivammathur/setup-php@v2
-        with:
-          php-version: 8.0
-          tools: composer:v2

      - name: Install dependencies
        run: composer install --prefer-dist

      - name: Execute Unit Tests
        run: phpdbg -qrr vendor/bin/phpunit --coverage-clover=clover.xml

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v2
        with:
          files: ./clover.xml
```
<p class="code-legend">exemplo usando docker</p>

A imagem desse exemplo é orientada para ser usada fora do Github também,
então eu tive de adicionar o `--user root`, porque alguns `actions` precisam
instalar pacotes (o `actions/checkout@v2` instala o `git` e outras coisas).

Mas essa não é a única forma de usar o imagens do Docker se você ou a
ferramenta que você normalmente usa tiver uma imagem para ser usada, então pode
adicionar a mesma como um `step`:

```yaml
name: "PHPInsights"
on:
  pull_request:
  push:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: PHPInsights
        uses: docker://nunomaduro/phpinsights
        with:
          args: --format=github-action
```
<p class="code-legend">docker como um `step`</p>

Se ela tiver um formato de saída compatível com os [annotations commands][]
então fica parecendo que é uma `action` nativa.

Podemos ainda executar Docker in Docker se for necessário combinar a sua imagem
própria e usar outra imagem como um `step`.

```yaml {linenos=table,hl_lines=["10-12","21-24"]}
name: "PHPCS (Docker in Docker)"
on:
  pull_request:
  push:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/lucassabreu/php-with-exts-example:main
      options: --user root

    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Install dependencies
        run: composer install --prefer-dist

      - name: PHPCS
        uses: docker://phpqa/phpcs
        with:
          args: sh -c "phpcs src --report=emacs | sed \"s|^.*src|src|;s|\(.*\):\(.*\):\(.*\):\(.*\)|::error file=\1,line=\2,col=\3::\4|\""
```
<p class="code-legend">docker in docker</p>

### Secrets

Ainda tem um ponto importante para vários fluxos de CI (e principalmente
Continuous Delivery), que é lidar com informações sensíveis (chaves RSA, tokens
de acesso, JWTs, OAuth Client secrets, senhas).

Exceto quando o seu CI esta integrado com o provedor que irá executar o seu
ambiente (Openshift/Kubernetes), é provável que você vai precisar ter alguma
chave para poder se conectar a sua VPS, seja para copiar arquivos via RSYNC,
fazer o push de imagens para registros do Docker, conectar via SSH, ou apenas
disparar algum evento no seu provedor.

E ter essa chave aberta no YAML do `workflow` esta longe de ser uma boa
prática, para resolver esse problema o Github permite que registremos valores
para o repositório que são acessíveis apenas dentro do `actions`.

Os "segredos do repositório", que são acessíveis em todos os `workflows`
abertamente (exceto por forks que nesse caso precisa que um colaborador
aprove).

![github-secrets](./github-secrets.png#class=big "segredos do repositório")

Como falei, esses caras ficam disponíveis para todos os `workflows`, e pode ser
usados simplesmente usando o contexto `secrets` no YAML.

Por exemplo, se o seu repositório for privado, o Codecov obriga você a usar um
token para enviar o relatório de cobertura.

```yaml {linenos=table,hl_lines=["4"],linenostart=30}
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v2
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: ./clover.xml
```

Agora sempre que o `workflow` for executado o Github vai automaticamente
injetar o segredo na `step`.

## Outros eventos e usos

Agora que temos uma ideia de como criar os `workflows` e também como combinar
`actions` prontas, seja do [Github Marketplace][marketplace] ou imagens do
Docker.

Vamos dar uma explorada em alguns outros eventos interessantes que podemos usar
nos `actions` que podem ser usados para alguns comportamentos customizados.

### CRON

As CRONs no Github Actions rodam automaticamente com base numa periodicidade
que você definir, sempre usando a branch padrão do projeto.

Com esse evento podemos, por exemplo, avaliar se PRs ou Issues no Github estão
abertas por muito tempo, e dessa forma podem ser um risco, e marcar eles como
`stale`, ou notificar o time no Slack para não ser esquecida.

Também pode usá-lo para rodar processos que sejam muito grandes/lentos para se
executar num PR ou no merge da branch.

Outros usos legais são para automatizar e melhorar o seu perfil do Github, como
o `gautamkrishnar/blog-post-workflow` e o `athul/waka-readme`.

O [`gautamkrishnar/blog-post-workflow`][blog-action] consulta o RSS to seu blog
e insere as ultimas postagens que você fez.

E o [`athul/waka-readme`][waka-action] puxa os dados do [Wakatime][] e cria um
gráfico ASCII com base neles.

![github-file](./github-cron-profile.png#class=big "exemplo de cron alterando perfil do github")

### Comments e Labels

Também podemos ouvir quando são feitos comentários ou modificadas as `labels`
de um PR ou Issue.

Com ele podemos automatizar a subida de ambientes quando formos testar o mesmo,
ou visualizar como uma postagem vai ficar sem de fato publicar ela nosso blog
pessoal.

```yaml {linenos=table,hl_lines=["3-4","8"]}
name: GH Pages (Preview PR)
on:
  pull_request:
    types: [labeled]

jobs:
  build-and-preview:
    if: ${{ github.event.label.name == 'preview-pr' }}
    runs-on: ubuntu-latest
    steps:
      - name: Checkout 🛎️
        uses: actions/checkout@v2.3.1
        with:
          submodules: true
          fetch-depth: 0

      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v2
        with:
          hugo-version: "0.87.0"

      - name: Build
        run: |
          REL=preview/${{ github.event.number }}
          hugo -d public/$REL -v --minify \
            -b http://www.lucassabreu.net.br/$REL

      - name: Deploy 🚀
        uses: JamesIves/github-pages-deploy-action@4.1.5
        with:
          branch: gh-pages
          folder: public
          clean: false
```
<p class="code-legend">trigger preview deploy</p>

Se quiser ainda pode usar o `actions/github-script` para remover a `label` no
fim do deploy, e colocar outra para indicar que concluiu. Mas já deixar pronto
para iniciar o deploy de novo.

```yaml {linenos=table,linenostart=34}
      - uses: actions/github-script@v4
        if: ${{ always() }}
        with:
          script: |
            github.issues.removeLabel({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.payload.number,
              name: 'preview-pr'
            })
            github.issues.addLabels({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.payload.number,
              labels: ['preview-deployed']
            })
```

## Criar Actions

Para criar uma `action` e publicar ela basta criar um repositório público no
Github, adicionar um [`action.yaml`][action-yaml] na raiz do projeto, e
publicar uma release, ao registrar ele irá confirmar se deseja adicionar no
marketplace e em qual categoria.

![marketplace-release](./marketplace-release.png#class=big)


#
## o que é o github actions
## no que temos usado o github actions/ci
## exemplos para pull request/push
### sh/bash, annotations usando output format
### usar typescript com actions kit
### usar imagens do docker/dockerfile action
## eventos interessantes
### cron: wakatime profile
### issue comment
### workflow_dispatch: gh workflow run
## usar os runners em infra própria

[Drone CI]: <wip>
[Buildkite]: <wip>
[Coderockr]: https://coderockr.com
[commit status]: oi
[deployment status]: oi
[annotations]: https://docs.github.com/en/github/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/about-status-checks#checks
[dispatch]: #dispatch
[lucassabreu/github-actions-examples]: https://github.com/lucassabreu/github-actions-examples
[PHPStan]: <wip>
[Phan]: <wip>
[PHPMD]: <wip>
[PHPCS]: <wip>
[PHP CS Fixer]: <wip>
[Codecov]: <wip>
[marketplace]: https://github.com/marketplace/actions
[codecov-action]: https://github.com/marketplace/actions/codecov
[log-commands]: https://docs.github.com/en/actions/reference/workflow-commands-for-github-actions
[sed]: https://github.com/lucassabreu/github-actions-examples/blob/f051cee06d489998f90e4e4cb6fc71afcc5fc7ca/.github/workflows/phpcs.yaml#L35-L38
[action-yaml]: https://docs.github.com/en/actions/creating-actions/metadata-syntax-for-github-actions
[annotations commands]: #lintsanalise-estática-com-annotations
[wakatime]: <wip>
[waka-action]: https://github.com/athul/waka-readme
[blog-action]: https://github.com/gautamkrishnar/blog-post-workflow

