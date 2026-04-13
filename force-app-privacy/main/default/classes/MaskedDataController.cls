public with sharing class MaskedDataController {

    public class MaskedContact {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String birthdate;
        @AuraEnabled public String description;
        @AuraEnabled public String accountName;
        @AuraEnabled public String accountDescription;
    }

    @AuraEnabled(cacheable=true)
    public static List<MaskedContact> getMaskedContacts() {
        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Email, Phone, Birthdate,
                   Description, Account.Name, Account.Description
            FROM Contact
            ORDER BY LastName
            LIMIT 200
        ];

        List<MaskedContact> result = new List<MaskedContact>();
        for (Contact c : contacts) {
            MaskedContact mc = new MaskedContact();
            mc.id = c.Id;
            mc.name = maskName(c.FirstName, c.LastName);
            mc.email = maskEmail(c.Email);
            mc.phone = maskPhone(c.Phone);
            mc.birthdate = maskBirthdate(c.Birthdate);
            mc.description = maskDescription(c.Description);
            mc.accountName = c.Account != null ? c.Account.Name : '';
            mc.accountDescription = maskDescription(c.Account != null ? c.Account.Description : null);
            result.add(mc);
        }
        return result;
    }

    private static String maskName(String firstName, String lastName) {
        String masked = '';
        if (firstName != null && firstName.length() > 0) {
            masked += firstName.substring(0, 1) + '***';
        }
        if (lastName != null && lastName.length() > 0) {
            masked += ' ' + lastName.substring(0, 1) + '***';
        }
        return masked.trim();
    }

    private static String maskEmail(String email) {
        if (email == null || !email.contains('@')) return '***@***.***';
        String[] parts = email.split('@');
        String local = parts[0];
        String domain = parts[1];
        String maskedLocal = local.length() > 1
            ? local.substring(0, 1) + '***'
            : local + '***';
        String maskedDomain = domain.length() > 2
            ? domain.substring(0, 1) + '***' + domain.substring(domain.lastIndexOf('.'))
            : '***';
        return maskedLocal + '@' + maskedDomain;
    }

    private static String maskPhone(String phone) {
        if (phone == null || phone.length() < 4) return '***-****';
        return phone.substring(0, phone.length() - 4).replaceAll('[0-9]', '*') + phone.substring(phone.length() - 4);
    }

    private static String maskBirthdate(Date d) {
        if (d == null) return '****-**-**';
        return '****-**-' + String.valueOf(d.day()).leftPad(2, '0');
    }

    private static String maskDescription(String rawText) {
        if (rawText == null || rawText.length() == 0) return '';

        String masked = rawText;
        masked = masked.replaceAll('\\b\\d{6}-\\d{4}\\b', '******-****');
        masked = masked.replaceAll('\\b\\d{4}-\\d{4}-\\d{4}-\\d{4}\\b', '****-****-****-****');
        masked = masked.replaceAll('\\bCVV:\\s*\\d{3}\\b', 'CVV: ***');
        masked = masked.replaceAll('\\bExp:\\s*\\d{2}/\\d{2}\\b', 'Exp: **/**');
        masked = masked.replaceAll('\\b[A-Z]{2}\\d{2}[A-Z0-9]{4,}\\d{7,}[A-Z0-9]{0,16}\\b', '****IBAN****');
        masked = masked.replaceAll('\\b\\d{9,18}\\b', '****');
        masked = masked.replaceAll('Salary:\\s*\\d+', 'Salary: ******');
        masked = masked.replaceAll('[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}', '***@***.***');

        return masked;
    }
}
