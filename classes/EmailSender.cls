public class EmailSender {
    public static void sendEmail(List<Lead> newLeads) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Lead ld : newLeads) {
            if (ld.Email != null) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                String [] toAddress = new String[]{ld.Email};
                email.setToAddresses(toAddress);
                email.setSubject('New Lead Created: ' + ld.LastName);

                String body = 'A new Lead has been created with the following details:\n\n'
                            + 'Name: ' + ld.Name + '\n'
                            + 'Company: ' + ld.Company + '\n'
                            + 'Email: ' + ld.Email + '\n';

                email.setPlainTextBody(body);
                emails.add(email);
            }
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
}