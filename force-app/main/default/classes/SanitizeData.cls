global class SanitizeData implements SandboxPostCopy {

    global void runApexClass(SandboxContext context) {
        sanitize();
    }

    public static void sanitize() {
        scrambleContactEmails();
        scrambleContactPhones();
    }

    private static void scrambleContactEmails() {
        List<Contact> contacts = [
            SELECT Id, Email
            FROM Contact
            WHERE Email != null
            LIMIT 10000
        ];

        for (Contact c : contacts) {
            c.Email = c.Id + '@example.invalid';
        }

        if (!contacts.isEmpty()) {
            update contacts;
        }
    }

    private static void scrambleContactPhones() {
        List<Contact> contacts = [
            SELECT Id, Phone, MobilePhone
            FROM Contact
            WHERE Phone != null OR MobilePhone != null
            LIMIT 10000
        ];

        for (Contact c : contacts) {
            c.Phone = '555-000-0000';
            c.MobilePhone = '555-000-0000';
        }

        if (!contacts.isEmpty()) {
            update contacts;
        }
    }
}
