+++
draft = false
images = ["/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-1/header.png"]
tags = ["Kubernetes","Openshift","Introduction","Simple","Docker"]
toc = false
date = "2017-03-07"
title = "Um ambiente simples usando Kubernetes e OpenShift Next Gen - Parte 1"
description = "Como parte das minhas metas dentro da Coderockr está a construção de um cluster usando algumas das ferramentas de orquestração de contêineres que existem no mercado; como o Docker Swarm, Kubernetes, Apache Mesos, etc. Optei pelo Kubernetes..."
next = "/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-2/"
+++

<!--more-->

{{< figure class="big" src="/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-1/header.png" >}}

Como parte das minhas metas dentro da [Coderockr](http://blog.coderockr.com) está a construção de um cluster usando algumas das ferramentas de orquestração de contêineres que existem no mercado; como o [Docker Swarm](https://docs.docker.com/engine/swarm/), [Kubernetes](http://kubernetes.io), [Apache Mesos](http://mesos.apache.org/), etc.

Optei pelo **Kubernetes** no momento, tanto pelo pedigree, criado pelo Google e mantido pela Cloud Native Computing Foundation; quanto pela oferta de grandes clouds como a Red Hat, Azure e Google.

Quando estava avaliando as opções disponíveis, o [Jean Carlo Machado](https://medium.com/@JeanCarloMachad) (colega da [CompuFácil](https://medium.com/@compufacil)), me sugeriu usar o [**OpenShift Next Gen**](https://blog.openshift.com/next-generation-openshift-online/), a plataforma da Red Hat para Kubernetes, que esta em [Developer Preview](https://www.openshift.com/devpreview/) permitindo que você se cadastre para testar a ferramenta deles por 30 dias.

Isso me salvou de já ter de sair pagando para testar, ou ter de fazer o [setup do minikube](https://kubernetes.io/docs/getting-started-guides/minikube/) na minha máquina, o que não me era muito atrativo.

Assim resolvi dar uma chance a plataforma da Red Hat, e construir um ambiente simples com um servidor HTTP em Node e um banco de dados MySQL, o que já me permite cobrir vários aspectos básicos do Kubernetes.

Mas como o texto foi ficando muito grande, achei melhor quebrá-lo em 4 partes para não cansar quem for ler e que irei publicar nos próximos dias.

Nessa primeira parte vou dar uma introdução aos conceitos básicos do Kubernetes, e nas próximas irei fazer uso desses conceitos.

- Parte 2 - Construindo o Ambiente: [clique aqui](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-2/)
- Parte 3 - Volumes Persistentes: [clique aqui](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-3/)
- Parte 4 - Segredos: [clique aqui](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-4/)

* * *

A aplicação que construí usa um [conjunto de dados sobre faltas em consultas](https://www.kaggle.com/joniarroba/noshowappointments) que achei no [Kaggle](https://www.kaggle.com/) e gera os gráficos abaixo, podendo escolher o dia da semana como filtro.

{{< figure src="/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-1/app-view.png"
        title="O fonte dessa aplicação pode ser encontrado aqui: <https://github.com/lucassabreu/openshift-next-gen/tree/app>" >}}

Então publiquei no [Docker Hub](http://hub.docker.com) uma imagem para a aplicação ([lucassabreu/openshift-app-test](https://hub.docker.com/r/lucassabreu/openshift-app-test/)) e outra para o banco de dados ([lucassabreu/openshift-mysql-test](https://hub.docker.com/r/lucassabreu/openshift-mysql-test/)) - essa imagem é um MySQL normal, mas que adicionei um dump da base que vou usar para facilitar o deploy.

Agora se eu quiser executar essa aplicação na minha máquina, posso simplesmente executar os seguintes comando do Docker e terei o servidor me respondendo em `http://localhost`:

```bash
#!/bin/bash
docker run -d --name db-test \
  -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=appointments \
  -e MYSQL_USER=appoint -e MYSQL_PASSWORD=123 \
  lucassabreu/openshift-mysql-test

docker run -d --name app-test --link db-test:db \
  -e DATABASE_CONNECTION=mysql://appoint:123@$db:3306/appointments \
  -p 80:8080 lucassabreu/openshift-app-test
```

Certo, agora que tenho certeza de que a minha aplicação está operacional, comecei a criar os objetos do Kubernetes, mas antes é importante entender alguns conceitos da plataforma para não ficar muito perdido:

#### [Pod](https://kubernetes.io/docs/user-guide/pods/)

Este é o menor componente do Kubernetes, representa um nó no cluster, executando um ou mais contêineres que entregam uma mesma função.

Eles tem a característica de serem descartáveis, ou seja, se eventualmente acontecer algum problema a um Pod, este pode ser destruído sem nenhum efeito colateral ou remorso.

#### [Deployment](https://kubernetes.io/docs/user-guide/deployments/)

Como o nome sugere controla o deploy de Pods dentro do cluster. Quando se cria esse componente, deve-se informar um template de Pod e quantos destes você precisa, e se necessário uma regra para criar mais instâncias.

Ele irá garantir duas coisas principalmente: que existam suficientes Pods quanto foi definido, e que os mesmos estejam atualizados em relação ao template que foi definido.

Então caso você mude algo no template o Deployment vai subir novos Pods e destruir os antigos para manter a expectativa (ele também "versiona" os deploys, então se algo explodir dá para voltar atrás).

#### [Service](https://kubernetes.io/docs/user-guide/services/)

Como os Pods além de efêmeros, podem existir em números variados por culpa dos Deployments, não há forma confiável de tentar conectar dois Pods diretamente, seja porque o Pod que você está dependendo pode morrer e quando voltar terá outro IP, e provavelmente outro nome, ou porque o Pod que você "fixou" pode não ser o mas indicado (menos ocupado ou mais próximo).

Para resolver esse problema existem os Services, em vez de tentar fazer as chamadas diretamente para um Pod, podemos chamar pelo nome de um Service e este irá rotear para um Pod que esteja abaixo dele.

É importante ressaltar que os Services fazem "apenas" a descoberta dos Pods, eles não os mantêm ligados, isso é responsabilidade dos Deployments.

#### [Route](https://docs.openshift.org/latest/architecture/core_concepts/routes.html)

Permitem que você exponha Services para a rede externa e também permite algumas regras de proxy para melhor apresentá-los.

Embora seja possível fazer a exposição de Services para a rede externa com Kubernetes, na plataforma da OpenShift é necessário o uso do componente Route para isso.

* * *

Como comentei no início, estou escrevendo uma série de postagens para mostrar como usar o básico do Kubernetes, e no próximo post irei usar os conceitos que acabei de descrever para implementar o ambiente.

Próximo Post: [clique aqui](/post/um-ambiente-simples-usando-kubernetes-e-openshift-next-gen-parte-2/)
