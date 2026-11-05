# Point rainhater.com at the server (GoDaddy)

You'll need the server's IP address (four numbers like 164.90.12.34). I'll give it to you.

1. Sign in at godaddy.com and open **My Products**.
2. Next to **rainhater.com**, click **DNS** (or the three dots, then **Manage DNS**).
3. If you see **Forwarding** turned on for the domain, turn it off.
4. In the **DNS Records** list, find the record with **Type: A** and **Name: @**. Click the pencil to edit it.
   - Value: the server IP
   - TTL: 600 seconds (or the lowest choice)
   - Save. If there's more than one A record named @, delete the extras.
5. Find the record with **Name: www**. It's usually **Type: CNAME** pointing to `@` or to `rainhater.com`. If so, leave it alone.
   - If there's no www record, click **Add New Record**: Type **A**, Name **www**, Value the server IP, TTL 600. Save.
6. Don't touch the **NS** or **SOA** records.

That's it. It usually starts working within 15 to 60 minutes. Tell me when it's saved and I'll turn on HTTPS.
