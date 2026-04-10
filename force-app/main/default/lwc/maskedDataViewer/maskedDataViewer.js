import { LightningElement, wire } from 'lwc';
import getMaskedContacts from '@salesforce/apex/MaskedDataController.getMaskedContacts';

const COLUMNS = [
    { label: 'Name', fieldName: 'name', type: 'text' },
    { label: 'Account', fieldName: 'accountName', type: 'text' },
    { label: 'Email', fieldName: 'email', type: 'text' },
    { label: 'Phone', fieldName: 'phone', type: 'text' },
    { label: 'Birthdate', fieldName: 'birthdate', type: 'text' },
    { label: 'Contact Notes', fieldName: 'description', type: 'text', wrapText: true },
    { label: 'Account Notes', fieldName: 'accountDescription', type: 'text', wrapText: true }
];

export default class MaskedDataViewer extends LightningElement {
    columns = COLUMNS;
    contacts = [];
    error;
    totalRecords = 0;

    @wire(getMaskedContacts)
    wiredContacts({ error, data }) {
        if (data) {
            this.contacts = data;
            this.totalRecords = data.length;
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : 'Unknown error';
            this.contacts = [];
        }
    }

    get hasData() {
        return this.contacts.length > 0;
    }

    get noData() {
        return this.contacts.length === 0;
    }

    get subtitle() {
        return `${this.totalRecords} contacts — all sensitive fields are masked server-side before reaching the browser`;
    }

    handleExportCsv() {
        if (!this.contacts.length) return;

        const headers = ['Name', 'Account', 'Email', 'Phone', 'Birthdate', 'Contact Notes', 'Account Notes'];
        const fields = ['name', 'accountName', 'email', 'phone', 'birthdate', 'description', 'accountDescription'];

        let csv = headers.join(',') + '\n';
        this.contacts.forEach(row => {
            const values = fields.map(f => {
                const val = (row[f] || '').toString().replace(/"/g, '""');
                return `"${val}"`;
            });
            csv += values.join(',') + '\n';
        });

        const encodedCsv = encodeURIComponent(csv);
        const dataUrl = 'data:text/csv;charset=utf-8,' + encodedCsv;
        const link = this.template.querySelector('[data-id="downloadLink"]');
        link.href = dataUrl;
        link.download = 'masked_contact_data.csv';
        link.click();
    }
}
