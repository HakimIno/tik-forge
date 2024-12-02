declare module 'tik-forge' {
    /**
     * Generate PDF from HTML
     * @param html HTML content to convert
     * @param options PDF generation options
     */
    export function generatePDF(html: string, options?: PDFOptions): Buffer;

    export interface PDFOptions {
        password?: {
            userPassword?: string;
            ownerPassword?: string;
            permissions?: {
                printing?: boolean;
                modifying?: boolean;
                copying?: boolean;
                annotating?: boolean;
            };
        };
    }

    /**
     * Initialize the module
     */
    export function init(): boolean;
} 