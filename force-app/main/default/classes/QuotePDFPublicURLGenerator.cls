/**
 * @description Genera URLs públicas para PDFs de Quotes CPQ
 * @author Francisco Perez - Tekiio
 * @date 2026-02
 */
public class QuotePDFPublicURLGenerator {
    
    /**
     * @description Invocable method para generar URL pública del PDF del Quote
     * Se llama desde Flow cuando Quote pasa a "Cerrada Ganada"
     * @param requests Lista de requests con Quote IDs
     * @return Lista de resultados con URLs públicas generadas
     */
    @InvocableMethod(
        label='Generate Public PDF URL' 
        description='Migra Attachment a ContentVersion y crea URL pública'
        category='Quote'
    )
    public static List<Result> generatePublicPDFURL(List<Request> requests) {
        List<Result> results = new List<Result>();
        
        for (Request req : requests) {
            Result res = new Result();
            res.quoteId = req.quoteId;
            
            try {
                res.publicURL = processQuote(req.quoteId);
                res.success = true;
                res.message = 'URL pública generada exitosamente';
                
            } catch (NoQuoteDocumentException e) {
                res.success = false;
                res.message = e.getMessage();
                
            } catch (Exception e) {
                res.success = false;
                res.message = 'Error: ' + e.getMessage();
                System.debug(LoggingLevel.ERROR, 'Error generando URL pública: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }
            
            results.add(res);
        }
        
        return results;
    }
    
    /**
     * @description Procesa un Quote para generar su URL pública
     * @param quoteId ID del Quote
     * @return URL pública del PDF
     */
    private static String processQuote(Id quoteId) {
        
        // 1. Verificar si ya tiene URL pública
        SBQQ__Quote__c quote = getQuote(quoteId);
        
        if (String.isNotBlank(quote.PDF_Public_URL__c)) {
            System.debug('Quote ya tiene URL pública: ' + quote.PDF_Public_URL__c);
            return quote.PDF_Public_URL__c;
        }
        
        // 2. Obtener QuoteDocument más reciente
        SBQQ__QuoteDocument__c quoteDoc = getQuoteDocument(quoteId);
        
        // 3. Verificar si ya existe ContentDistribution
        String existingURL = getExistingContentDistribution(quoteDoc.Name);
        
        if (String.isNotBlank(existingURL)) {
            System.debug('ContentDistribution ya existe, reutilizando: ' + existingURL);
            updateQuoteURL(quoteId, existingURL);
            return existingURL;
        }
        
        // 4. Migrar Attachment a ContentVersion
        Id contentVersionId = migrateAttachmentToContent(
            quoteDoc.SBQQ__AttachmentId__c, 
            quoteId, 
            quoteDoc.Name
        );
        
        // 5. Crear ContentDistribution
        String publicURL = createContentDistribution(contentVersionId, quoteDoc.Name);
        
        // 6. Actualizar Quote con la URL
        updateQuoteURL(quoteId, publicURL);
        
        System.debug('URL pública generada exitosamente: ' + publicURL);
        return publicURL;
    }
    
    /**
     * @description Obtiene el Quote por ID
     */
    private static SBQQ__Quote__c getQuote(Id quoteId) {
        return [
            SELECT Id, PDF_Public_URL__c 
            FROM SBQQ__Quote__c 
            WHERE Id = :quoteId
            LIMIT 1
        ];
    }
    
    /**
     * @description Obtiene el QuoteDocument más reciente del Quote
     */
    private static SBQQ__QuoteDocument__c getQuoteDocument(Id quoteId) {
        List<SBQQ__QuoteDocument__c> quoteDocs = [
            SELECT Id, Name, SBQQ__AttachmentId__c 
            FROM SBQQ__QuoteDocument__c 
            WHERE SBQQ__Quote__c = :quoteId 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        if (quoteDocs.isEmpty()) {
            throw new NoQuoteDocumentException(
                'No existe QuoteDocument para este Quote. ' +
                'Por favor genere el documento primero usando "Generate Document".'
            );
        }
        
        SBQQ__QuoteDocument__c quoteDoc = quoteDocs[0];
        
        if (String.isBlank(quoteDoc.SBQQ__AttachmentId__c)) {
            throw new NoQuoteDocumentException(
                'El QuoteDocument no tiene un Attachment asociado.'
            );
        }
        
        return quoteDoc;
    }
    
    /**
     * @description Verifica si ya existe ContentDistribution para este documento
     */
    private static String getExistingContentDistribution(String documentName) {
        List<ContentDistribution> existingCD = [
            SELECT DistributionPublicUrl 
            FROM ContentDistribution 
            WHERE Name LIKE :('%' + documentName + '%')
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        return existingCD.isEmpty() ? null : existingCD[0].DistributionPublicUrl;
    }
    
    /**
     * @description Migra Attachment a ContentVersion (Files)
     * @param attachmentId ID del Attachment
     * @param quoteId ID del Quote (para vincular el archivo)
     * @param fileName Nombre del archivo
     * @return ID del ContentVersion creado
     */
    private static Id migrateAttachmentToContent(Id attachmentId, Id quoteId, String fileName) {
        
        // Obtener Attachment
        Attachment att = [
            SELECT Name, Body, ContentType 
            FROM Attachment 
            WHERE Id = :attachmentId
            LIMIT 1
        ];
        
        // Crear ContentVersion
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName + '.pdf';
        cv.VersionData = att.Body;
        cv.FirstPublishLocationId = quoteId;
        cv.Origin = 'H'; // Uploaded content
        
        insert cv;
        
        System.debug('ContentVersion creado: ' + cv.Id);
        return cv.Id;
    }
    
    /**
     * @description Crea ContentDistribution y retorna URL pública
     * @param contentVersionId ID del ContentVersion
     * @param name Nombre para la distribución
     * @return URL pública del PDF
     */
    private static String createContentDistribution(Id contentVersionId, String name) {
        
        ContentDistribution cd = new ContentDistribution();
        cd.Name = 'PDF - ' + name;
        cd.ContentVersionId = contentVersionId;
        cd.PreferencesAllowViewInBrowser = true;
        cd.PreferencesLinkLatestVersion = true;
        cd.PreferencesNotifyOnVisit = false;
        cd.PreferencesPasswordRequired = false;
        cd.PreferencesExpires = false;
        
        insert cd;
        
        // Obtener URL pública
        ContentDistribution cdInserted = [
            SELECT DistributionPublicUrl 
            FROM ContentDistribution 
            WHERE Id = :cd.Id
            LIMIT 1
        ];
        
        System.debug('ContentDistribution creado: ' + cd.Id);
        return cdInserted.DistributionPublicUrl;
    }
    
    /**
     * @description Actualiza el campo PDF_Public_URL__c del Quote
     */
    private static void updateQuoteURL(Id quoteId, String publicURL) {
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            Id = quoteId,
            PDF_Public_URL__c = publicURL
        );
        update quote;
    }
    
    // ========== INNER CLASSES ==========
    
    /**
     * @description Request input para Invocable Method
     */
    public class Request {
        @InvocableVariable(required=true label='Quote ID' description='ID del Quote CPQ')
        public Id quoteId;
    }
    
    /**
     * @description Result output del Invocable Method
     */
    public class Result {
        @InvocableVariable(label='Quote ID')
        public Id quoteId;
        
        @InvocableVariable(label='Public URL')
        public String publicURL;
        
        @InvocableVariable(label='Success')
        public Boolean success;
        
        @InvocableVariable(label='Message')
        public String message;
    }
    
    /**
     * @description Custom exception para cuando no existe QuoteDocument
     */
    public class NoQuoteDocumentException extends Exception {}

}