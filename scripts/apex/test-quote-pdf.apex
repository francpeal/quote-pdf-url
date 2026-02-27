// Script de testing manual para QuotePDFPublicURLGenerator
// Ejecutar desde VS Code: Ctrl+Shift+P → "SFDX: Execute Anonymous Apex"

// 1. Obtener un Quote existente (ajusta el nombre según tu org)
List<SBQQ__Quote__c> quotes = [
    SELECT Id, Name, SBQQ__Status__c, PDF_Public_URL__c
    FROM SBQQ__Quote__c
    WHERE SBQQ__Status__c = 'Closed Won'
    LIMIT 1
];

if (quotes.isEmpty()) {
    System.debug('❌ No se encontraron Quotes en estado Closed Won');
    System.debug('💡 Crea un Quote y pásalo a Closed Won primero');
} else {
    SBQQ__Quote__c quote = quotes[0];
    System.debug('📋 Quote encontrado: ' + quote.Name);
    System.debug('   ID: ' + quote.Id);
    System.debug('   Status: ' + quote.SBQQ__Status__c);
    System.debug('   URL actual: ' + quote.PDF_Public_URL__c);
    
    // 2. Ejecutar la generación de URL pública
    QuotePDFPublicURLGenerator.Request req = new QuotePDFPublicURLGenerator.Request();
    req.quoteId = quote.Id;
    
    System.debug('\n🚀 Generando URL pública...\n');
    
    List<QuotePDFPublicURLGenerator.Result> results = 
        QuotePDFPublicURLGenerator.generatePublicPDFURL(
            new List<QuotePDFPublicURLGenerator.Request>{req}
        );
    
    // 3. Mostrar resultado
    QuotePDFPublicURLGenerator.Result result = results[0];
    
    if (result.success) {
        System.debug('✅ ÉXITO!');
        System.debug('📄 URL Pública: ' + result.publicURL);
        System.debug('💬 Mensaje: ' + result.message);
    } else {
        System.debug('❌ ERROR');
        System.debug('💬 Mensaje: ' + result.message);
    }
}