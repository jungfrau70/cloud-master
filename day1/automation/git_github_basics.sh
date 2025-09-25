#!/bin/bash
# Git/GitHub   

set -e

echo " Git/GitHub   ..."

# Git  
echo " Git  :"
git --version
git config --global user.name || echo " Git   ."
git config --global user.email || echo " Git   ."

# Git  ()
if [ -z "$(git config --global user.name)" ]; then
    echo " Git   ."
    read -p "Git  : " git_username
    git config --global user.name "$git_username"
fi

if [ -z "$(git config --global user.email)" ]; then
    echo " Git   ."
    read -p "Git  : " git_email
    git config --global user.email "$git_email"
fi

#   
echo "   ..."
mkdir -p git-practice
cd git-practice

# Git  
git init

# .gitignore 
cat > .gitignore << 'EOF'
node_modules/
.env
*.log
.DS_Store
dist/
build/
EOF

# README.md 
cat > README.md << 'EOF'
# Git Practice Repository

  Git/GitHub    .

##  
- Git  
-  
-  
- GitHub 

## 
```bash
git clone <repository-url>
cd git-practice
npm install
npm start
```
EOF

#   
git add .
git commit -m "Initial commit: Add README and .gitignore"

#    
echo "    ..."
git checkout -b feature/docker-setup

# Docker   
cat > Dockerfile << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
EOF

#   
git add .
git commit -m "Add Docker configuration"

#   
git checkout main

#  
git merge feature/docker-setup

#  
git branch -d feature/docker-setup

#   
echo "  :"
git log --oneline --graph

# GitHub  ()
echo " GitHub     ..."
echo "GitHub       :"
echo "git remote add origin <repository-url>"
echo "git push -u origin main"

echo " Git/GitHub   !"
