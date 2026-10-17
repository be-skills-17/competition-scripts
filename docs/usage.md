# Using the environment

Start with the portal, `https://<domain>/`: log in with your competition username and password to get your
credentials, website URLs, database names and Git repository URLs, ready to copy.

- **Git Server (Gitea):**
  Access through the `git` subdomain of your configured domain.
  - Example: `https://git.local.skill17.com`
  - Default admin: `admin` / `your_secure_password`

- **Competitors' Work:**
  Competitors' projects can be accessed using their subdomain and the module name.
  - Format: `https://<subdomain>-<module_name>.<domain>`
  - Example: `https://qwer-module-a.local.skill17.com`

- **Database Entries:**
  MySQL is automatically configured with:
  - Per-competitor databases: `comp01_module_a`, `comp01_module_b`, etc.
  - Automatic user creation with appropriate permissions
  - Users can access only their own databases

## Competitor Workflow

### Creating a Repository

1. **Access Gitea:**
   Open your Git server (e.g., `https://git.local.skill17.com`) and log in using your credentials.

2. **Choose a Framework Template:**
   Go to `organization -> frameworks` to pick a framework template for your repository. The templates include necessary Docker configurations and GitHub Actions workflows ready to use.

3. **Use the Template:**
   Click **"Use this template"** to create your repository. Name the repository to match the module name defined in the configuration file.
   - Example: If your module is `module-a`, name the repository `module-a`.

4. **Environment Setup:**
   The framework template automatically includes:
   - Dockerfile for containerization
   - GitHub Actions workflow for CI/CD
   - `.npmrc` with correct registry configuration (auto-replaced with your domain)
   - GitHub Actions secrets (USER, PASS, DOMAIN, NPM_REGISTRY_URL, SERVER_IP)

5. **Test the Setup:**
   Make a commit to verify that GitHub Actions are working correctly. The workflow should build and push your image to `git.domain/username/module_name:version`.

### Cloning and using the Repository

1. Clone the repository:
   ```bash
   git clone https://<username>:<password>@git.local.skill17.com/<username>/<module_name>.git
   cd <module_name>
   ```

2. Install dependencies (if using Node.js):
   ```bash
   npm install
   ```

3. Develop your code:
   - Edit, commit, and push frequently
   - Use branches for features/fixes
   - Always keep your README updated

4. Push your code:
   ```bash
   git push origin main
   ```
   This triggers the GitHub Actions workflow which builds your Docker image and pushes it to the registry.
