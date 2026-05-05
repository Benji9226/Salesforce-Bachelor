import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchReports from '@salesforce/apex/SafeReportExportController.searchReports';
import runRawReport from '@salesforce/apex/SafeReportExportController.runRawReport';
import applyStrategyToColumn from '@salesforce/apex/SafeReportExportController.applyStrategyToColumn';
import loadRecord from '@salesforce/apex/SafeReportExportController.loadRecord';
import searchRecords from '@salesforce/apex/SafeReportExportController.searchRecords';
import saveCatalogueRules from '@salesforce/apex/SafeReportExportController.saveCatalogueRules';
import hasCataloguePerm from '@salesforce/customPermission/Modify_Masking_Catalogue';

// Each entry has the friendly `label` shown to the user, the dropdown
// `value`, and the actual `strategyClass` + `paramsJson` the Apex
// dispatcher needs. The "Fake X" rows bundle parameters so the user
// does not have to know about library names — picking "Fake First
// Name" is exactly equivalent to picking LibraryStrategy with
// {"libraryName":"FIRST_NAME"} but the dropdown reads as a task,
// not as an implementation detail.
const STRATEGY_OPTIONS = [
    { label: 'None (raw)', value: 'None',
      strategyClass: 'None', paramsJson: null },

    { label: 'Fake First Name', value: 'FakeFirstName',
      strategyClass: 'LibraryStrategy',
      paramsJson: '{"libraryName":"FIRST_NAME"}' },
    { label: 'Fake Last Name', value: 'FakeLastName',
      strategyClass: 'LibraryStrategy',
      paramsJson: '{"libraryName":"LAST_NAME"}' },
    { label: 'Fake Company Name', value: 'FakeCompany',
      strategyClass: 'LibraryStrategy',
      paramsJson: '{"libraryName":"COMPANY"}' },
    { label: 'Fake Email', value: 'FakeEmail',
      strategyClass: 'FakeEmailStrategy', paramsJson: null },
    { label: 'Fake Phone', value: 'FakePhone',
      strategyClass: 'FakePhoneStrategy', paramsJson: null },
    { label: 'Redact Patterns', value: 'RedactPatterns',
      strategyClass: 'RedactPatternsStrategy', paramsJson: null },

    { label: 'Nullify', value: 'NullStrategy',
      strategyClass: 'NullStrategy', paramsJson: null },
    { label: 'Redact ****', value: 'RedactStrategy',
      strategyClass: 'RedactStrategy', paramsJson: null },
    { label: 'Scramble (random)', value: 'ScrambleStrategy',
      strategyClass: 'ScrambleStrategy', paramsJson: null },
    { label: 'Hash (SHA-256)', value: 'HashStrategy',
      strategyClass: 'HashStrategy', paramsJson: null },
    { label: 'Format-Preserving Caesar', value: 'FormatPreservingStrategy',
      strategyClass: 'FormatPreservingStrategy', paramsJson: null },

    { label: 'Einstein AI', value: 'EinsteinAI',
      strategyClass: 'EinsteinAI', paramsJson: null }
];

const COMBOBOX_OPTIONS = STRATEGY_OPTIONS.map(o => ({
    label: o.label, value: o.value
}));

const OPTIONS_BY_VALUE = STRATEGY_OPTIONS.reduce((acc, o) => {
    acc[o.value] = o;
    return acc;
}, {});

const OBJECT_OPTIONS = [
    { label: 'Account', value: 'Account' },
    { label: 'Contact', value: 'Contact' },
    { label: 'Lead', value: 'Lead' },
    { label: 'Opportunity', value: 'Opportunity' },
    { label: 'Case', value: 'Case' }
];

// Heuristic mapping from a header / API name fragment to the
// dropdown value the "Suggest Strategies" button should pre-pick.
// Order matters: the first match wins, so put the more specific
// patterns ("first name") before the more generic ones ("name").
const SUGGEST_RULES = [
    { test: /first[\s_]*name|firstname|givenname|fornavn/i, value: 'FakeFirstName' },
    { test: /last[\s_]*name|lastname|surname|familyname|efternavn/i, value: 'FakeLastName' },
    { test: /company|account[\s_]*name|organi[sz]ation|virksomhed/i, value: 'FakeCompany' },
    { test: /e[-_]?mail/i, value: 'FakeEmail' },
    { test: /phone|mobile|fax|telefon/i, value: 'FakePhone' },
    { test: /description|notes?|comments?|beskrivelse/i, value: 'RedactPatterns' }
];

function suggestForLabel(text) {
    if (!text) return null;
    for (const rule of SUGGEST_RULES) {
        if (rule.test.test(text)) {
            return rule.value;
        }
    }
    return null;
}

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

    strategyOptions = COMBOBOX_OPTIONS;
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

    get suggestDisabled() {
        return !this.hasRawPreview || this.isLoading;
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

    get detailSuggestDisabled() {
        return !this.detailHasRecord || this.detailIsLoading;
    }

    get canModifyCatalogue() {
        return hasCataloguePerm === true;
    }

    get savePromotableFields() {
        return this.detailFields.filter(f => {
            const opt = OPTIONS_BY_VALUE[f.strategy];
            if (!opt) return false;
            if (opt.value === 'None') return false;
            if (opt.strategyClass === 'EinsteinAI') return false;
            return true;
        });
    }

    get saveCatalogueDisabled() {
        return !this.detailHasRecord || this.savePromotableFields.length === 0;
    }

    get saveCatalogueLabel() {
        const n = this.savePromotableFields.length;
        if (!this.detailHasRecord) return 'Save as Catalogue Rules';
        return `Save ${n} Rule${n === 1 ? '' : 's'} to Catalogue`;
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

    handleStrategyChange(event) {
        const idx = parseInt(event.target.dataset.idx, 10);
        const newStrategy = event.detail.value;
        return this.applyStrategyToColumnIdx(idx, newStrategy);
    }

    async applyStrategyToColumnIdx(idx, optionValue) {
        const config = this.columnConfigs[idx];
        if (!config) return;
        const opt = OPTIONS_BY_VALUE[optionValue];
        if (!opt) return;

        this.updateColumnConfig(idx, {
            strategy: optionValue,
            isLoading: optionValue !== 'None',
            isMasked: false
        });

        if (optionValue === 'None') {
            this.applyColumnValues(idx, this.rawColumns[idx]);
            this.updateColumnConfig(idx, { isLoading: false, isMasked: false });
            return;
        }

        try {
            const masked = await applyStrategyToColumn({
                values: this.rawColumns[idx],
                strategyName: opt.strategyClass,
                paramsJson: opt.paramsJson
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

    async handleSuggestColumns() {
        if (!this.hasRawPreview) return;
        const tasks = this.columnConfigs.map(config => {
            const suggestion = suggestForLabel(config.label);
            return suggestion ? this.applyStrategyToColumnIdx(config.idx, suggestion) : null;
        }).filter(Boolean);
        const applied = tasks.length;
        await Promise.all(tasks);
        this.dispatchEvent(new ShowToastEvent({
            title: applied > 0
                ? `Suggested masking applied to ${applied} column${applied === 1 ? '' : 's'}`
                : 'No matching columns to suggest',
            message: applied > 0
                ? 'Columns matching FirstName / LastName / Email / Phone / Company / Description heuristics have been masked. Adjust per column as needed.'
                : 'None of the column headers matched the built-in name / email / phone / description heuristics.',
            variant: applied > 0 ? 'success' : 'warning'
        }));
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

    handleDetailStrategyChange(event) {
        const fieldApi = event.target.dataset.field;
        const newStrategy = event.detail.value;
        return this.applyStrategyToDetailField(fieldApi, newStrategy);
    }

    async applyStrategyToDetailField(fieldApi, optionValue) {
        const idx = this.detailFields.findIndex(f => f.fieldApiName === fieldApi);
        if (idx === -1) return;
        const opt = OPTIONS_BY_VALUE[optionValue];
        if (!opt) return;

        const field = this.detailFields[idx];
        this.updateDetailField(idx, {
            strategy: optionValue,
            isLoading: optionValue !== 'None',
            isMasked: false
        });

        if (optionValue === 'None') {
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
                strategyName: opt.strategyClass,
                paramsJson: opt.paramsJson
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

    async handleSuggestFields() {
        if (!this.detailHasRecord) return;
        const tasks = this.detailFields.map(field => {
            const hint = (field.fieldApiName || '') + ' ' + (field.fieldLabel || '');
            const suggestion = suggestForLabel(hint);
            return suggestion ? this.applyStrategyToDetailField(field.fieldApiName, suggestion) : null;
        }).filter(Boolean);
        const applied = tasks.length;
        await Promise.all(tasks);
        this.dispatchEvent(new ShowToastEvent({
            title: applied > 0
                ? `Suggested masking applied to ${applied} field${applied === 1 ? '' : 's'}`
                : 'No matching fields to suggest',
            message: applied > 0
                ? 'Fields matching FirstName / LastName / Email / Phone / Company / Description heuristics have been masked. The record on disk is unchanged.'
                : 'None of the field names matched the built-in name / email / phone / description heuristics.',
            variant: applied > 0 ? 'success' : 'warning'
        }));
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

    async handleSaveCatalogueRules() {
        const promotable = this.savePromotableFields;
        if (promotable.length === 0) return;

        const rules = promotable.map(f => {
            const opt = OPTIONS_BY_VALUE[f.strategy];
            return {
                objectApi: this.detailObjectApi,
                fieldApi: f.fieldApiName,
                strategyClass: opt.strategyClass,
                paramsJson: opt.paramsJson
            };
        });

        try {
            const result = await saveCatalogueRules({ rules });
            const enq = result && result.rulesEnqueued != null ? result.rulesEnqueued : 0;
            const skp = result && result.rulesSkipped != null ? result.rulesSkipped : 0;
            const deployId = result && result.deploymentId ? result.deploymentId : '(none)';

            if (enq > 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: `Promoted ${enq} rule${enq === 1 ? '' : 's'} to the catalogue`,
                    message: `Deployment ${deployId} enqueued. ${skp} rule${skp === 1 ? '' : 's'} skipped.`,
                    variant: 'success',
                    mode: 'sticky'
                }));
            } else {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'No rules promoted',
                    message: `${skp} rule${skp === 1 ? '' : 's'} skipped — see browser console for details.`,
                    variant: 'warning'
                }));
            }
            if (result && result.skippedReasons && result.skippedReasons.length > 0) {
                // eslint-disable-next-line no-console
                console.log('[Mask Workbench] Skipped rules:', result.skippedReasons);
            }
            this.detailError = undefined;
        } catch (err) {
            this.detailError = err.body ? err.body.message : 'Failed to save catalogue rules';
            this.dispatchEvent(new ShowToastEvent({
                title: 'Save failed',
                message: this.detailError,
                variant: 'error'
            }));
        }
    }
}
