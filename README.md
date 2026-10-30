# Deetty e Dintor

Deetty é o terminal e Dintor é o editor que acompanham a DINX. Este repositório mantém o slug upstream `rufl/NOCTTY`; alguns nomes internos e arquivos de build ainda usam os identificadores históricos `NOCTTY`/`NoctEd` para preservar a compatibilidade do código-fonte.

## Snapshot de código-fonte

Este snapshot alpha está publicado para permitir a reprodução e auditoria dos pacotes DINX. A DINX fixa um commit e um checksum imutáveis ao construir os aplicativos. O snapshot não representa uma release estável independente, suporte geral nem qualificação para uso diário.

O código de primeiro nível usa MIT. Dependências vendorizadas e dados gerados mantêm suas próprias licenças; consulte [LICENSE](LICENSE) e [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). O build requer Zig 0.17.x; veja também a [arquitetura](docs/pt-BR/architecture.md) e a [compatibilidade](docs/pt-BR/compatibility.md).

O empacotamento e os contratos de integração da DINX ficam em [rufl/DINX](https://github.com/rufl/DINX).
