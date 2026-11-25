# E-commerce Data Platform — Terraform M03

Projekt definiuje infrastrukturę dla przetwarzania zamówień e-commerce w AWS i Azure. Główna konfiguracja obsługuje AWS, a katalog `azure/` zawiera osobną konfigurację uruchomieniową dla Azure.

## Architektura

```text

AWS — eu-north-1

  S3 raw → Glue orders-etl-job → S3 processed

  S3 curated

  RDS PostgreSQL → VPC z dwiema prywatnymi podsieciami

  Terraform state → S3 + blokada DynamoDB

Azure — West Europe

  ADLS Gen2 → bronze / silver / gold

  Key Vault → sekret połączenia z ADLS

```

## Moduły

- `modules/glue_job` definiuje rolę wykonawczą, jej uprawnienia i job Glue. Główna konfiguracja przesyła `glue_scripts/orders_etl.py` do S3 i przekazuje modułowi adres skryptu.

- `modules/azure_datalake` definiuje Resource Group, konto ADLS Gen2, trzy systemy plików oraz Key Vault z sekretem połączenia.

Skrypt PySpark czyta zamówienia z plików Parquet w `raw/orders/`, konwertuje typy, odrzuca nieprawidłowe rekordy i usuwa duplikaty po `order_id` w obrębie jednego uruchomienia. Wynik dopisuje jako Parquet do `processed/orders/`, w partycjach `year=.../month=...` według daty zamówienia. Ponowne przetworzenie tych samych danych może dopisać duplikaty.

## Uruchomienie AWS

Wymagane są Terraform, AWS CLI, profil `ecommerce-dev` i uprawnienia do zasobów projektu w `eu-north-1`. Przed pierwszym `terraform init` przygotuj bucket stanu wskazany w `main.tf` oraz tabelę DynamoDB `terraform-state-lock`. Bucket powinien mieć włączone wersjonowanie, a tabela klucz partycji `LockID` typu String.

Z głównego folderu projektu uruchom w PowerShellu:

```powershell

$tf = "$HOME\terraform-bin\terraform.exe"

aws sts get-caller-identity --profile ecommerce-dev

& $tf init

& $tf validate

$hasloRds = Read-Host 'Haslo dla dbadmin' -AsSecureString

$env:TF_VAR_db_password = [System.Net.NetworkCredential]::new('', $hasloRds).Password

& $tf plan '-var=env=dev' '-var=create_glue_job=false'

```

Przy istniejącej bazie użyj dotychczasowego hasła. Po sprawdzeniu planu uruchom:

```powershell

& $tf apply '-var=env=dev' '-var=create_glue_job=false'

& $tf plan '-var=env=dev' '-var=create_glue_job=false'

```

Opcja `create_glue_job=false` pozwala wdrożyć pozostałe zasoby na koncie użytym w projekcie. Na koncie z dostępem do `glue:CreateJob` ustaw `create_glue_job=true`, aby Terraform utworzył także job.

Hasło jest przekazywane przez `TF_VAR_db_password`. Pliki stanu, zapisane plany i pliki `.tfvars` pozostają poza repozytorium. Do repozytorium trafia wzór `terraform.tfvars.example`.

## Uruchomienie Azure

Z głównego folderu projektu można zwalidować konfigurację Azure bez aktywnej subskrypcji:

```powershell

$tf = "$HOME\terraform-bin\terraform.exe"

& $tf '-chdir=azure' init

& $tf '-chdir=azure' validate

```

Do wdrożenia potrzebna jest aktywna subskrypcja i uprawnienia do tworzenia zasobów. Po zalogowaniu przez `az login` wybierz właściwą subskrypcję, sprawdź plan i dopiero potem uruchom `apply`:

```powershell

az login

az account show --query state -o tsv

& $tf '-chdir=azure' plan

& $tf '-chdir=azure' apply

```

Azure używa osobnego stanu Terraform. Nazwa konta Storage musi być globalnie unikalna. Można ją zmienić w `azure/main.tf`.

## Wynik wdrożenia

| Obszar | Wynik |
|---|---|
| Backend AWS | Utworzono bucket stanu S3 i tabelę blokady DynamoDB w Sztokholmie. |
| S3 | `Apply complete! Resources: 12 added, 0 changed, 0 destroyed.` Utworzono trzy buckety wraz z konfiguracją zabezpieczeń. |
| RDS i sieć | `Apply complete! Resources: 6 added, 0 changed, 0 destroyed.` Utworzono bazę `db.t3.micro` i prywatną sieć. |
| AWS Glue | Wgrano skrypt do S3 i utworzono rolę wykonawczą z politykami. AWS odrzucił `CreateJob` komunikatem `Account is denied access`. Job pozostaje zdefiniowany w kodzie. |
| Weryfikacja AWS | Plan z `create_glue_job=false` zwrócił `No changes`. Po dodaniu `s3_bucket_names` kolejny plan wykazał wyłącznie zmianę wartości wyjściowej. |
| Azure | `terraform init` i `terraform validate` zakończyły się pomyślnie. Wdrożenie pozostaje niewykonane z powodu braku aktywnej subskrypcji. |

RDS działa na PostgreSQL `15.19`, ponieważ wersji `15.4` nie było na liście dostępnych wersji w Sztokholmie. Dostęp do portu `5432` ograniczono do zakresu VPC `10.0.0.0/16`.

## Rozwiązywanie problemów

1. **`AccessDenied` z informacją o SCP przy tworzeniu bucketa.** Sprawdź region przypisany do projektu AWS. W tym projekcie utworzenie bucketa zadziałało w `eu-north-1`.

2. **`Saved plan is stale`.** Po zmianie stanu wygeneruj świeży plan przed kolejnym wdrożeniem.

3. **`Account is denied access` przy `CreateJob`.** Na tym koncie użyj `create_glue_job=false`, aby zaplanować i wdrożyć pozostałe zasoby.

4. **`Please run 'az login' to setup account`.** `plan` i `apply` w katalogu `azure/` wymagają zalogowania i aktywnej subskrypcji. Samo `validate` można wykonać bez logowania.

5. **Ostrzeżenie o `dynamodb_table`.** Terraform oznacza ten parametr jako wycofywany. Projekt zachowuje go, ponieważ zaliczenie wymaga blokady DynamoDB.

