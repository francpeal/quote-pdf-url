/**
 * @description Test class para QuotePDFPublicURLGenerator
 * @author Francisco Perez - Tekiio
 * @date 2026-02
 */
@isTest
public class QuotePDFPublicURLGeneratorTest {
    
    /**
     * @description Setup de datos de test
     */
    @TestSetup
    static void setup() {
        // Crear Account
        Account acc = new Account(
            Name = 'Test Account Motorex',
            MOT_LineaNegocio__c = '24'  // ← AQUÍ va el campo
        );
        insert acc;
        
        // Crear Quote con campo requerido MOT_LineaNegocio__c
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Status__c = 'Draft',
            SBQQ__Primary__c = true
            //MOT_LineaNegocio__c = 'Otros'  // Campo requerido en Motorex
        );
        insert quote;
        
        // Crear QuoteDocument
        SBQQ__QuoteDocument__c qd = new SBQQ__QuoteDocument__c(
            SBQQ__Quote__c = quote.Id,
            Name = 'Q-TEST-20260225-0001'
        );
        insert qd;
        
        // Crear Attachment (simulando PDF generado)
        Attachment att = new Attachment(
            Name = 'Quote-Test.pdf',
            Body = Blob.valueOf('Test PDF Content - This is a test'),
            ParentId = quote.Id,
            ContentType = 'application/pdf'
        );
        insert att;
        
        // Actualizar QuoteDocument con AttachmentId
        qd.SBQQ__AttachmentId__c = att.Id;
        update qd;
    }
    
    /**
     * @description Test: Genera URL pública exitosamente
     */
    @isTest
    static void testGeneratePublicURL_Success() {
        // Obtener Quote de test
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        // Preparar request
        QuotePDFPublicURLGenerator.Request req = new QuotePDFPublicURLGenerator.Request();
        req.quoteId = quote.Id;
        
        Test.startTest();
        List<QuotePDFPublicURLGenerator.Result> results = 
            QuotePDFPublicURLGenerator.generatePublicPDFURL(
                new List<QuotePDFPublicURLGenerator.Request>{req}
            );
        Test.stopTest();
        
        // Validaciones
        System.assertEquals(1, results.size(), 'Debe retornar 1 resultado');
        
        QuotePDFPublicURLGenerator.Result result = results[0];
        System.assertEquals(true, result.success, 'Debe ser exitoso');
        System.assertNotEquals(null, result.publicURL, 'Debe generar URL pública');
        System.assert(result.publicURL.contains('http'), 'URL debe ser válida');
        
        // Verificar que se actualizó el Quote
        quote = [SELECT PDF_Public_URL__c FROM SBQQ__Quote__c WHERE Id = :quote.Id];
        System.assertNotEquals(null, quote.PDF_Public_URL__c, 'Quote debe tener URL pública');
        System.assertEquals(result.publicURL, quote.PDF_Public_URL__c, 'URLs deben coincidir');
    }
    
    /**
     * @description Test: Reutiliza URL si ya existe
     */
    @isTest
    static void testGeneratePublicURL_AlreadyExists() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        // Simular que ya tiene URL pública
        String existingURL = 'https://motorex.file.force.com/test/existing';
        quote.PDF_Public_URL__c = existingURL;
        update quote;
        
        QuotePDFPublicURLGenerator.Request req = new QuotePDFPublicURLGenerator.Request();
        req.quoteId = quote.Id;
        
        Test.startTest();
        List<QuotePDFPublicURLGenerator.Result> results = 
            QuotePDFPublicURLGenerator.generatePublicPDFURL(
                new List<QuotePDFPublicURLGenerator.Request>{req}
            );
        Test.stopTest();
        
        // Validar que reutiliza la URL existente
        System.assertEquals(1, results.size());
        QuotePDFPublicURLGenerator.Result result = results[0];
        System.assertEquals(true, result.success, 'Debe ser exitoso');
        System.assertEquals(existingURL, result.publicURL, 'Debe reutilizar URL existente');
    }
    
    /**
     * @description Test: Falla cuando no existe QuoteDocument
     */
    @isTest
    static void testGeneratePublicURL_NoQuoteDocument() {
        // Crear Quote sin QuoteDocument
        Account acc = new Account(
            Name = 'Test Account 2',
            MOT_LineaNegocio__c = '24'  // ← AQUÍ también
        );
        insert acc;
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Status__c = 'Draft'
            //MOT_LineaNegocio__c = 'Otros'  // Campo requerido
        );
        insert quote;
        
        QuotePDFPublicURLGenerator.Request req = new QuotePDFPublicURLGenerator.Request();
        req.quoteId = quote.Id;
        
        Test.startTest();
        List<QuotePDFPublicURLGenerator.Result> results = 
            QuotePDFPublicURLGenerator.generatePublicPDFURL(
                new List<QuotePDFPublicURLGenerator.Request>{req}
            );
        Test.stopTest();
        
        // Validar que falla apropiadamente
        System.assertEquals(1, results.size());
        QuotePDFPublicURLGenerator.Result result = results[0];
        System.assertEquals(false, result.success, 'Debe fallar porque no hay QuoteDocument');
        System.assert(
            result.message.contains('No existe QuoteDocument'), 
            'Mensaje debe indicar que falta QuoteDocument'
        );
    }
    
    /**
     * @description Test: Procesa múltiples Quotes en batch
     */
    @isTest
    static void testGeneratePublicURL_MultipleBatch() {
        // Crear segundo Quote
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        SBQQ__Quote__c quote2 = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Status__c = 'Draft'
            //MOT_LineaNegocio__c = 'Otros'  // Campo requerido
        );
        insert quote2;
        
        SBQQ__QuoteDocument__c qd2 = new SBQQ__QuoteDocument__c(
            SBQQ__Quote__c = quote2.Id,
            Name = 'Q-TEST-20260225-0002'
        );
        insert qd2;
        
        Attachment att2 = new Attachment(
            Name = 'Quote-Test-2.pdf',
            Body = Blob.valueOf('Test PDF Content 2'),
            ParentId = quote2.Id,
            ContentType = 'application/pdf'
        );
        insert att2;
        
        qd2.SBQQ__AttachmentId__c = att2.Id;
        update qd2;
        
        // Obtener ambos Quotes
        List<SBQQ__Quote__c> quotes = [SELECT Id FROM SBQQ__Quote__c];
        System.assertEquals(2, quotes.size(), 'Deben existir 2 quotes');
        
        // Preparar requests
        List<QuotePDFPublicURLGenerator.Request> requests = new List<QuotePDFPublicURLGenerator.Request>();
        for (SBQQ__Quote__c q : quotes) {
            QuotePDFPublicURLGenerator.Request req = new QuotePDFPublicURLGenerator.Request();
            req.quoteId = q.Id;
            requests.add(req);
        }
        
        Test.startTest();
        List<QuotePDFPublicURLGenerator.Result> results = 
            QuotePDFPublicURLGenerator.generatePublicPDFURL(requests);
        Test.stopTest();
        
        // Validar que ambos fueron procesados exitosamente
        System.assertEquals(2, results.size(), 'Deben procesarse 2 quotes');
        for (QuotePDFPublicURLGenerator.Result result : results) {
            System.assertEquals(true, result.success, 'Todos deben ser exitosos');
            System.assertNotEquals(null, result.publicURL, 'Todos deben tener URL');
        }
    }
}