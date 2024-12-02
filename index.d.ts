declare module 'tik-forge' {
    /**
     * Initialize the addon
     */
    export function init(): void;

    /**
     * Generate PDF from HTML
     * @param html HTML content to convert
     * @returns Buffer containing PDF data
     */
    export function generatePDF(html: string): Buffer;

    // เพิ่ม type definitions สำหรับ functions อื่นๆ ที่มี
} 