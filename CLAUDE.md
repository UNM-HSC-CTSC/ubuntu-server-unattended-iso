# Ubuntu Server Unattended ISO Builder

A tool for creating custom Ubuntu Server installation ISOs with automated installation configurations. 
Users can use provided configurations or generate custom autoinstall.yaml files via an interactive wizard.

## Current State (December 2024)

### Major Refactoring in Progress
The project is being restructured to follow industry standards:

**✅ Completed:**
- Created `lib/` directory with shared libraries (common.sh, download.sh, validate.sh)
- Moved test scripts to `tests/` directory  
- Created `share/` directory with ubuntu-base and examples
- Fixed GitHub Actions and removed ISO building from CI (storage optimization)
- Implemented role-based deployment system with cloud-init
- Created comprehensive documentation in `docs/`
- Deployed GitHub Enterprise infrastructure with runners
- Added MCP servers to Claude Docker container (Context7, Sequential Thinking, Perplexity)

**🔄 Still TODO:**
- Rename bin commands to `ubuntu-iso` and `ubuntu-iso-generate`
- Remove duplicate scripts from `scripts/`
- Update build-iso to use new lib functions
- Create LICENSE, CONTRIBUTING.md
- Update README to reflect new structure

### Recent Major Changes
- **GitHub Role**: Complete rewrite from Gitea to GitHub Actions runners
- **Bootstrap Architecture**: Two-phase approach for infrastructure dependencies
- **Windows/Hyper-V**: Full PowerShell automation for VM deployment
- **Cloud-Init Integration**: Role-based server configuration via metadata
- **Claude Docker**: Enhanced with pre-configured MCP servers for better AI assistance

## Next Steps

### Immediate Tasks
1. Complete industry-standard restructure (bin/, lib/, share/)
2. Clean up legacy scripts and profiles directories
3. Finalize command renaming for better usability
4. Update all documentation to reflect new structure

### Future Enhancements
- Web UI for ISO generation
- ARM64 architecture support
- HashiCorp Vault integration for secrets
- Kubernetes deployment support
- Automated compliance scanning

## Quick Reference

### Key Commands
```bash
# Build ISO
./bin/build-iso --profile ubuntu-base

# Generate custom autoinstall  
./bin/generate-autoinstall

# Test infrastructure
NO_COLOR=1 ./test.sh

# Deploy VM (Windows/Hyper-V)
./deploy/Deploy-VM.ps1 -Role github -VMName hsc-ctsc-github-01

# Run Claude with MCP servers
export PERPLEXITY_API_KEY=your-key  # Optional
cd claude && ./run_claude.sh
```

### Project Structure
```
/app/
├── bin/                 # User commands (build-iso, generate-autoinstall)
├── lib/                 # Shared libraries
├── share/              # Data files and examples
├── tests/              # Test scripts
├── ansible/            # Ansible roles and playbooks
├── deploy/             # PowerShell deployment scripts
├── docs/               # Comprehensive documentation
├── profiles/           # Server profiles (being migrated to share/)
└── claude/             # Claude Docker container with MCP servers
    ├── .claude/        # Persistent config including .mcp.json
    └── *.sh/.ps1       # Build and run scripts
```

### Important Paths
- Config Server: `hsc-ctsc-config.health.unm.edu`
- Repository Server: `hsc-ctsc-repository.health.unm.edu`
- Docker Build: `./docker-build.ps1` (Windows) or `./docker-build.sh` (Linux)

## Key Technical Decisions

- **No external dependencies**: Uses only native Linux tools (mount, python3, etc.)
- **Cloud-init metadata**: Role assignment via metadata, NOT MAC addresses
- **Pull-based configuration**: Servers fetch config via ansible-pull
- **Two-phase bootstrap**: Manual infrastructure servers, then automated deployment
- **No Terraform/Pulumi**: Simple PowerShell scripts for Hyper-V automation
- **GitOps principles**: All configuration in version control

## Important Notes

### Do's
- Use cloud-init metadata for server roles
- Store secrets in vault (never in Git)
- Follow the two-phase bootstrap process
- Use DNS for service discovery
- Test changes in isolated environments first

### Don'ts
- Don't use MAC addresses for role mapping
- Don't store credentials in autoinstall files
- Don't push configuration to servers (use pull)
- Don't skip validation when building ISOs
- Don't modify bootstrap servers after initial setup

### Environment Specifics
- Platform: Windows Server 2019 with Hyper-V
- Network: F5 BIG-IP handles DHCP/DNS
- Naming: `hsc-ctsc-[role]-[number]` format
- No public cloud (all on-premise)

## Documentation

For detailed information, see:
- `docs/ARCHITECTURE.md` - System design and technical architecture
- `docs/DEPLOYMENT-GUIDE.md` - Step-by-step deployment procedures
- `docs/ROLE-DEFINITIONS.md` - Available server roles and configurations
- `docs/BOOTSTRAP-GUIDE.md` - Infrastructure bootstrap process
- `docs/WINDOWS-DEPLOYMENT.md` - Hyper-V specific procedures
- `docs/GITHUB-INFRASTRUCTURE.md` - GitHub Enterprise and runners guide
- `claude/README.md` - Claude Docker container with MCP servers