# Contributing to Docker Compose Manager

Thank you for your interest in contributing to Docker Compose Manager! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful and considerate of others when contributing to this project.

## How to Contribute

### Reporting Issues

- Use the GitHub issue tracker
- Include a clear title and description
- Provide steps to reproduce the issue
- Include relevant logs and error messages
- Specify your environment (OS, Docker version, etc.)

### Feature Requests

- Use the GitHub issue tracker
- Clearly describe the feature
- Explain why it would be useful
- Include any relevant examples

### Pull Requests

1. Fork the repository
2. Create a new branch for your changes
3. Make your changes
4. Test your changes thoroughly
5. Submit a pull request

## Development Guidelines

### Adding New Templates

1. Create a new directory in `templates/` with your template name
2. Include all necessary files:
   - `docker-compose.yml`
   - `Dockerfile`
   - Required configuration files
   - Documentation

3. Update `templates/registry.json`:
   ```json
   {
     "templates": {
       "your-template": {
         "name": "Your Template Name",
         "description": "Description of your template",
         "version": "1.0.0",
         "url": "https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/templates/your-template",
         "files": [
           "docker-compose.yml",
           "Dockerfile",
           // other required files
         ],
         "tags": ["relevant", "tags", "for", "searching"]
       }
     }
   }
   ```

4. Add documentation:
   - Update `templates/README.md`
   - Add a README.md in your template directory

### Template Requirements

1. **Docker Configuration**:
   - Use official base images
   - Follow Docker best practices
   - Include health checks
   - Use environment variables for configuration

2. **Security**:
   - Don't include sensitive data
   - Use secure default configurations
   - Follow security best practices

3. **Documentation**:
   - Clear setup instructions
   - Environment variables documentation
   - Usage examples

4. **Testing**:
   - Include test configurations
   - Document testing procedures
   - Provide example tests

### Script Development

1. **Shell Scripts** (`manage.sh`):
   - Follow shell scripting best practices
   - Include error handling
   - Add comments for complex logic
   - Test on multiple Linux distributions

2. **PowerShell Scripts** (`manage.ps1`):
   - Follow PowerShell best practices
   - Use proper error handling
   - Add comments for complex logic
   - Test on Windows 10/11

## Testing

Before submitting a pull request:

1. Test your changes on:
   - Linux (Ubuntu, CentOS)
   - Windows 10/11
   - macOS (if applicable)

2. Verify:
   - Template creation works
   - All features function correctly
   - Error handling works as expected
   - Documentation is accurate

## Commit Guidelines

- Use clear, descriptive commit messages
- Reference issue numbers when applicable
- Keep commits focused and atomic

## License

By contributing to this project, you agree that your contributions will be licensed under the project's license. 