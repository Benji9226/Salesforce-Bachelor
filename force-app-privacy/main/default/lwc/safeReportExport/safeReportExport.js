import { LightningElement, track } from 'lwc';
import searchReports from '@salesforce/apex/SafeReportExportController.searchReports';
import runRawReport from '@salesforce/apex/SafeReportExportController.runRawReport';
import applyStrategyToColumn from '@salesforce/apex/SafeReportExportController.applyStrategyToColumn';
import loadRecord from '@salesforce/apex/SafeReportExportController.loadRecord';
import searchRecords from '@salesforce/apex/SafeReportExportController.searchRecords';

const STRATEGY_OPTIONS = [
    { label: 'None (raw)', value: 'None' },
    { label: 'Nullify', value: 'NullStrategy' },
    { label: 'Redact ****', value: 'RedactStrategy' },
    { label: 'Scramble (random)', value: 'ScrambleStrategy' },
    { label: 'Hash (SHA-256)', value: 'HashStrategy' },
    { label: 'Format-Preserving', value: 'FormatPreservingStrategy' },
    { label: 'Library (faker)', value: 'LibraryStrategy' },
    { label: 'Einstein AI', value: 'EinsteinAI' }
];

const OBJECT_OPTIONS = [
    { label: 'Account', value: 'Account' },
    { label: 'Contact', value: 'Contact' },
    { label: 'Lead', value: 'Lead' },
    { label: 'Opportunity', value: 'Opportunity' },
    { label: 'Case', value: 'Case' }
];

export default class SafeReportExport extends LightningElement {
    // Report tab state
    reportOptions = [];
    selectedReportId = '';
    selectedReportName = '';
    searchTerm = '';
    columns = [];
    @track currentRows = [];
    rawColumns = [];
    @track columnConfigs = [];
    totalRows = 0;
    isLoading = false;
    isSearching = false;
    hasRawPreview = false;
    showDropdown = false;
    error;

    // Detail tab state
    detailObjectApi = 'Account';
    detailRecordId = '';
    detailRecordName = '';
    detailObjectLabel = '';
    detailIsLoading = false;
    detailHasRecord = false;
    @track detailFields = [];
    detailError;
    detailSearchTerm = '';
    @track detailRecordOptions = [];
    detailIsSearching = false;
    detailShowDropdown = false;

    strategyOptions = STRATEGY_OPTIONS;
    objectOptions = OBJECT_OPTIONS;

    // ---- Report tab getters ----

    get hasData() {
        return this.hasRawPreview;
    }

    get noData() {
        return !this.hasData;
    }

    get exportDisabled() {
        return !this.hasRawPreview;
    }

    get previewDisabled() {
        return !this.selectedReportId || this.isLoading;
    }

    get anyMasked() {
        return this.columnConfigs.some(c => c.strategy && c.strategy !== 'None');
    }

    get resetDisabled() {
        return !this.hasRawPreview || !this.anyMasked;
    }

    get subtitle() {
        if (this.anyMasked) {
            return `${this.selectedReportName} — ${this.totalRows} rows — partial masking applied`;
        }
        if (this.hasRawPreview) {
            return `${this.selectedReportName} — ${this.totalRows} rows — RAW PREVIEW (sensitive data visible!)`;
        }
        return 'Search for a report, preview the raw data, then choose a masking strategy per column.';
    }

    get showWarningBadge() {
        return this.hasRawPreview && !this.anyMasked;
    }

    get showSuccessBadge() {
        return this.hasRawPreview && this.anyMasked;
    }

    get hasSearchResults() {
        return this.reportOptions.length > 0;
    }

    get searchPlaceholder() {
        return this.selectedReportId
            ? this.selectedReportName
            : 'Type at least 2 characters to search reports...';
    }

    get exportLabel() {
        return this.anyMasked ? 'Export Masked CSV' : 'Export CSV';
    }

    // ---- Detail tab getters ----

    get anyDetailMasked() {
        return this.detailFields.some(f => f.strategy && f.strategy !== 'None');
    }

    get detailResetDisabled() {
        return !this.detailHasRecord || !this.anyDetailMasked;
    }

    get detailSubtitle() {
        if (!this.detailHasRecord) {
            return 'Pick an object, type at least 2 characters of a record name, pick a match — then choose a masking strategy per field.';
        }
        if (this.anyDetailMasked) {
            return `${this.detailObjectLabel} — ${this.detailRecordName} — partial masking applied (record on disk is unchanged)`;
        }
        return `${this.detailObjectLabel} — ${this.detailRecordName} — RAW PREVIEW (record on disk is unchanged)`;
    }

    get detailWarningBadge() {
        return this.detailHasRecord && !this.anyDetailMasked;
    }

    get detailSuccessBadge() {
        return this.detailHasRecord && this.anyDetailMasked;
    }

    get detailHasSearchResults() {
        return this.detailRecordOptions.length > 0;
    }

    get detailSearchPlaceholder() {
        return `Type at least 2 characters of a ${this.detailObjectLabelForPlaceholder} name...`;
    }

    get detailObjectLabelForPlaceholder() {
        const found = OBJECT_OPTIONS.find(o => o.value === this.detailObjectApi);
        return found ? found.label : this.detailObjectApi;
    }

    // ---- Report tab handlers ----

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
        this.currentRows = [];
        this.rawColumns = [];
        this.columns = [];
        this.columnConfigs = [];
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
            const rows = this.mapRows(result.rows);
            this.currentRows = rows;
            this.rawColumns = result.headers.map((_h, idx) =>
                rows.map(r => (r['col_' + idx] == null ? '' : String(r['col_' + idx])))
            );
            this.columnConfigs = result.headers.map((h, idx) => ({
                idx,
                label: h,
                fieldName: 'col_' + idx,
                strategy: 'None',
                isLoading: false,
                isMasked: false
            }));
            this.totalRows = result.totalRows;
            this.selectedReportName = result.reportName;
            this.hasRawPreview = true;
        } catch (err) {
            this.error = err.body ? err.body.message : 'Failed to run report';
        } finally {
            this.isLoading = false;
        }
    }

    async handleStrategyChange(event) {
        const idx = parseInt(event.target.dataset.idx, 10);
        const newStrategy = event.detail.value;
        const config = this.columnConfigs[idx];
        if (!config) return;

        this.updateColumnConfig(idx, {
            strategy: newStrategy,
            isLoading: newStrategy !== 'None',
            isMasked: false
        });

        if (newStrategy === 'None') {
            this.applyColumnValues(idx, this.rawColumns[idx]);
            this.updateColumnConfig(idx, { isLoading: false, isMasked: false });
            return;
        }

        try {
            const masked = await applyStrategyToColumn({
                values: this.rawColumns[idx],
                strategyName: newStrategy,
                paramsJson: null
            });
            this.applyColumnValues(idx, masked);
            this.updateColumnConfig(idx, { isLoading: false, isMasked: true });
            this.error = undefined;
        } catch (err) {
            this.error = err.body ? err.body.message : 'Failed to apply strategy';
            this.applyColumnValues(idx, this.rawColumns[idx]);
            this.updateColumnConfig(idx, {
                strategy: 'None',
                isLoading: false,
                isMasked: false
            });
        }
    }

    updateColumnConfig(idx, patch) {
        this.columnConfigs = this.columnConfigs.map((c, i) =>
            i === idx ? { ...c, ...patch } : c
        );
    }

    applyColumnValues(colIdx, values) {
        const fieldName = 'col_' + colIdx;
        this.currentRows = this.currentRows.map((row, r) => ({
            ...row,
            [fieldName]: values && values[r] != null ? values[r] : ''
        }));
    }

    handleResetColumns() {
        const restored = this.currentRows.map((row, r) => {
            const next = { id: row.id };
            this.rawColumns.forEach((colVals, c) => {
                next['col_' + c] = colVals[r];
            });
            return next;
        });
        this.currentRows = restored;
        this.columnConfigs = this.columnConfigs.map(c => ({
            ...c,
            strategy: 'None',
            isLoading: false,
            isMasked: false
        }));
        this.error = undefined;
    }

    mapRows(rows) {
        return rows.map((row, rowIdx) => {
            const rowObj = { id: 'row_' + rowIdx };
            row.forEach((cell, colIdx) => {
                rowObj['col_' + colIdx] = cell == null ? '' : cell;
            });
            return rowObj;
        });
    }

    handleExportCsv() {
        if (!this.hasRawPreview) return;

        const headers = this.columns.map(c => c.label);
        let csv = headers.map(h => '"' + h.replace(/"/g, '""') + '"').join(',') + '\n';

        this.currentRows.forEach(row => {
            const values = this.columns.map(col => {
                const raw = row[col.fieldName];
                const val = (raw == null ? '' : String(raw)).replace(/"/g, '""');
                return '"' + val + '"';
            });
            csv += values.join(',') + '\n';
        });

        const safeName = this.selectedReportName.replace(/[^a-zA-Z0-9]/g, '_');
        const prefix = this.anyMasked ? 'masked_' : 'raw_';
        const encodedCsv = encodeURIComponent(csv);
        const dataUrl = 'data:text/csv;charset=utf-8,' + encodedCsv;
        const link = this.template.querySelector('[data-id="downloadLink"]');
        link.href = dataUrl;
        link.download = prefix + safeName + '.csv';
        link.click();
    }

    // ---- Detail tab handlers ----

    handleObjectChange(event) {
        this.detailObjectApi = event.detail.value;
        this.detailSearchTerm = '';
        this.detailRecordOptions = [];
        this.detailShowDropdown = false;
        this.detailRecordId = '';
        this.resetDetailRecord();
    }

    handleRecordSearchChange(event) {
        this.detailSearchTerm = event.target.value;
        if (this.detailSearchTerm.length >= 2) {
            this.doRecordSearch();
        } else {
            this.detailRecordOptions = [];
            this.detailShowDropdown = false;
        }
    }

    async doRecordSearch() {
        this.detailIsSearching = true;
        this.detailShowDropdown = true;
        try {
            this.detailRecordOptions = await searchRecords({
                objectApi: this.detailObjectApi,
                searchTerm: this.detailSearchTerm
            });
            this.detailError = undefined;
        } catch (err) {
            this.detailError = err.body ? err.body.message : 'Failed to search records';
            this.detailRecordOptions = [];
        } finally {
            this.detailIsSearching = false;
        }
    }

    handleRecordSearchFocus() {
        if (this.detailRecordOptions.length > 0) {
            this.detailShowDropdown = true;
        }
    }

    handleRecordSearchBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.detailShowDropdown = false; }, 200);
    }

    handleSelectRecordOption(event) {
        const recordId = event.currentTarget.dataset.id;
        const recordName = event.currentTarget.dataset.name;
        this.detailRecordId = recordId;
        this.detailRecordName = recordName;
        this.detailSearchTerm = recordName;
        this.detailShowDropdown = false;
        this.loadSelectedRecord();
    }

    resetDetailRecord() {
        this.detailHasRecord = false;
        this.detailFields = [];
        this.detailRecordName = '';
        this.detailObjectLabel = '';
    }

    async loadSelectedRecord() {
        this.detailIsLoading = true;
        this.detailError = undefined;
        this.resetDetailRecord();

        try {
            const result = await loadRecord({
                objectApi: this.detailObjectApi,
                recordId: this.detailRecordId
            });
            this.detailObjectLabel = result.objectLabel;
            this.detailRecordName = result.recordName;
            this.detailFields = result.fields.map(f => ({
                fieldApiName: f.fieldApiName,
                fieldLabel: f.fieldLabel,
                fieldType: f.fieldType,
                rawValue: f.value == null ? '' : String(f.value),
                currentValue: f.value == null ? '' : String(f.value),
                strategy: 'None',
                isLoading: false,
                isMasked: false
            }));
            this.detailHasRecord = true;
        } catch (err) {
            this.detailError = err.body ? err.body.message : 'Failed to load record';
        } finally {
            this.detailIsLoading = false;
        }
    }

    async handleDetailStrategyChange(event) {
        const fieldApi = event.target.dataset.field;
        const newStrategy = event.detail.value;
        const idx = this.detailFields.findIndex(f => f.fieldApiName === fieldApi);
        if (idx === -1) return;

        const field = this.detailFields[idx];
        this.updateDetailField(idx, {
            strategy: newStrategy,
            isLoading: newStrategy !== 'None',
            isMasked: false
        });

        if (newStrategy === 'None') {
            this.updateDetailField(idx, {
                currentValue: field.rawValue,
                isLoading: false,
                isMasked: false
            });
            return;
        }

        try {
            const masked = await applyStrategyToColumn({
                values: [field.rawValue],
                strategyName: newStrategy,
                paramsJson: null
            });
            const maskedValue = masked && masked[0] != null ? masked[0] : '';
            this.updateDetailField(idx, {
                currentValue: maskedValue,
                isLoading: false,
                isMasked: true
            });
            this.detailError = undefined;
        } catch (err) {
            this.detailError = err.body ? err.body.message : 'Failed to apply strategy';
            this.updateDetailField(idx, {
                currentValue: field.rawValue,
                strategy: 'None',
                isLoading: false,
                isMasked: false
            });
        }
    }

    updateDetailField(idx, patch) {
        this.detailFields = this.detailFields.map((f, i) =>
            i === idx ? { ...f, ...patch } : f
        );
    }

    handleResetDetailFields() {
        this.detailFields = this.detailFields.map(f => ({
            ...f,
            currentValue: f.rawValue,
            strategy: 'None',
            isLoading: false,
            isMasked: false
        }));
        this.detailError = undefined;
    }
}
