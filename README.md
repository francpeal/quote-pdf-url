# Quote PDF Public URL Generator

Generador automático de URLs públicas para PDFs de Quotes en Salesforce CPQ.

## 📋 Descripción

Cuando un Quote pasa a estado "Closed Won", este componente:
1. Detecta el cambio de estado automáticamente
2. Migra el PDF del Attachment a ContentVersion
3. Crea una ContentDistribution con URL pública
4. Guarda la URL en el campo `PDF_Public_URL__c`

Esta URL puede ser integrada con NetSuite u otros sistemas externos.

## 🚀 Componentes

- **Apex Class**: `QuotePDFPublicURLGenerator` - Lógica de generación de URLs
- **Apex Test**: `QuotePDFPublicURLGeneratorTest` - Cobertura de tests (100%)
- **Custom Field**: `PDF_Public_URL__c` en objeto Quote
- **Flow** (próximamente): Trigger automático en cambio de status

## 📦 Instalación

### Pre-requisitos
- Salesforce CPQ instalado
- VS Code con Salesforce Extension Pack
- Salesforce CLI

### Deploy

1. **Autenticar con tu org:**
```bash
sf org login web --alias motorex-prod
```

2. **Deploy a producción:**
```bash
sf project deploy start --target-org motorex-prod
```

3. **Ejecutar tests:**
```bash
sf apex run test --target-org motorex-prod --test-level RunLocalTests --wait 10
```

## 🧪 Testing Manual

1. Abrir `scripts/apex/test-quote-pdf.apex` en VS Code
2. Ejecutar: `Ctrl+Shift+P` → "SFDX: Execute Anonymous Apex"
3. Ver resultados en el Output panel

## 📖 Uso

### Automático (con Flow - próximamente)
El sistema se ejecuta automáticamente cuando un Quote pasa a "Closed Won"

### Manual (desde Apex)
```apex
QuotePDFPublicURLGenerator.Request req = new QuotePDFPublicURLGenerator.Request();
req.quoteId = 'a1TPd00000HRLrNMAX'; // Tu Quote ID

List<QuotePDFPublicURLGenerator.Result> results = 
    QuotePDFPublicURLGenerator.generatePublicPDFURL(
        new List<QuotePDFPublicURLGenerator.Request>{req}
    );

System.debug('URL: ' + results[0].publicURL);
```

## 🔗 Integración NetSuite

El campo `PDF_Public_URL__c` puede ser incluido en la integración SF→NS:
- Mapear a campo custom en Sales Order: `custbody_quote_pdf_url`
- Usar en reportes NetSuite para mostrar link al PDF

## 👨‍💻 Autor

**Francisco Perez**  
Development Team Leader - Grupo Tekiio  
Febrero 2026

## 📝 Licencia

Uso interno Motorex - Grupo Tekiio# quote-pdf-url
