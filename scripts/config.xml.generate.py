import yaml
from jinja2 import Environment, FileSystemLoader

# Load variables from YAML
with open('variables.yaml') as f:
    variables = yaml.safe_load(f)

# Set up Jinja2 environment
env = Environment(loader=FileSystemLoader('.'))
template = env.get_template('config.xml.j2')

# Render the template
output = template.render(variables)

# Write the output to config.xml
with open('config.xml', 'w') as f:
    f.write(output)