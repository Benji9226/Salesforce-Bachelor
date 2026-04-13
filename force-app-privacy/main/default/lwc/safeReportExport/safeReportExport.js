import { LightningElement } from 'lwc';
import searchReports from '@salesforce/apex/SafeReportExportController.searchReports';
import runRawReport from '@salesforce/apex/SafeReportExportController.runRawReport';
import runAndMaskReport from '@salesforce/apex/SafeReportExportController.runAndMaskReport';

export default class SafeReportExport extends LightningElement {
    reportOptions = [];
    selectedReportId = '';
    selectedReportName = '';
    searchTerm = '';
    columns = [];
    rawRows = [];
    maskedRows = [];
    totalRows = 0;
    isLoading = false;
    isSearching = false;
    isMasking = false;
    hasRawPreview = false;
    hasMaskedResults = false;
    showDropdown = false;
    error;

    get displayRows() {
        return this.hasMaskedResults ? this.maskedRows : this.rawRows;
    }

    get hasData() {
        return this.hasRawPreview || this.hasMaskedResults;
    }

    get noData() {
        return !this.hasData;
    }

    get maskDisabled() {
        return !this.hasRawPreview || this.isMasking || this.hasMaskedResults;
    }

    get exportDisabled() {
        return !this.hasMaskedResults || this.isMasking;
    }

    get previewDisabled() {
        return !this.selectedReportId || this.isLoading;
    }

    get subtitle() {
        if (this.hasMaskedResults) {
            return `${this.selectedReportName} — ${this.totalRows} rows — MASKED (sensitive data hidden)`;
        }
        if (this.hasRawPreview) {
            return `${this.selectedReportName} — ${this.totalRows} rows — RAW PREVIEW (sensitive data visible!)`;
        }
        return 'Search for a report, preview the raw data, then mask it before exporting';
    }

    get statusVariant() {
        if (this.hasMaskedResults) return 'success';
        if (this.hasRawPreview) return 'warning';
        return 'neutral';
    }

    get showWarningBadge() {
        return this.hasRawPreview && !this.hasMaskedResults;
    }

    get showSuccessBadge() {
        return this.hasMaskedResults;
    }

    get hasSearchResults() {
        return this.reportOptions.length > 0;
    }

    get searchPlaceholder() {
        return this.selectedReportId
            ? this.selectedReportName
            : 'Type at least 2 characters to search reports...';
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        if (this.searchTerm.length >= 2) {
            this.doSearch();
        } else {
            this.reportOptions = [];
            this.showDropdown = false;
        }
    }

    async doSearch() {
        this.isSearching = true;
        this.showDropdown = true;
        try {
            this.reportOptions = await searchReports({ searchTerm: this.searchTerm });
            this.error = undefined;
        } catch (err) {
            this.error = err.body ? err.body.message : 'Failed to search reports';
            this.reportOptions = [];
        } finally {
            this.isSearching = false;
        }
    }

    handleSelectReport(event) {
        const reportId = event.currentTarget.dataset.id;
        const reportName = event.currentTarget.dataset.name;
        this.selectedReportId = reportId;
        this.selectedReportName = reportName;
        this.searchTerm = reportName;
        this.showDropdown = false;
        this.resetResults();
    }

    handleSearchFocus() {
        if (this.reportOptions.length > 0) {
            this.showDropdown = true;
        }
    }

    handleSearchBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showDropdown = false; }, 200);
    }

    resetResults() {
        this.hasRawPreview = false;
        this.hasMaskedResults = false;
        this.rawRows = [];
        this.maskedRows = [];
        this.columns = [];
    }

    async handlePreview() {
        this.isLoading = true;
        this.error = undefined;
        this.resetResults();

        try {
            const result = await runRawReport({ reportId: this.selectedReportId });
            this.columns = result.headers.map((header, idx) => ({
                label: header,
                fieldName: 'col_' + idx,
                type: 'text',
                wrapText: true
            }));
            this.rawRows = this.mapRows(result.rows);
            this.totalRows = result.totalRows;
            this.selectedReportName = result.reportName;
            this.hasRawPreview = true;
        } catch (err) {
            this.error = err.body ? err.body.message : 'Failed to run report';
        } finally {
            this.isLoading = false;
        }
    }

    async handleMask() {
        this.isMasking = true;
        this.error = undefined;

        try {
            const result = await runAndMaskReport({ reportId: this.selectedReportId });
            this.maskedRows = this.mapRows(result.rows);
            this.hasMaskedResults = true;
        } catch (err) {
            this.error = err.body ? err.body.message : 'Failed to mask report';
        } finally {
            this.isMasking = false;
        }
    }

    mapRows(rows) {
        return rows.map((row, rowIdx) => {
            const rowObj = { id: 'row_' + rowIdx };
            row.forEach((cell, colIdx) => {
                rowObj['col_' + colIdx] = cell;
            });
            return rowObj;
        });
    }

    handleExportCsv() {
        if (!this.hasMaskedResults) return;

        const headers = this.columns.map(c => c.label);
        let csv = headers.map(h => '"' + h.replace(/"/g, '""') + '"').join(',') + '\n';

        this.maskedRows.forEach(row => {
            const values = this.columns.map(col => {
                const val = (row[col.fieldName] || '').toString().replace(/"/g, '""');
                return '"' + val + '"';
            });
            csv += values.join(',') + '\n';
        });

        const safeName = this.selectedReportName.replace(/[^a-zA-Z0-9]/g, '_');
        const encodedCsv = encodeURIComponent(csv);
        const dataUrl = 'data:text/csv;charset=utf-8,' + encodedCsv;
        const link = this.template.querySelector('[data-id="downloadLink"]');
        link.href = dataUrl;
        link.download = 'masked_' + safeName + '.csv';
        link.click();
    }
}
