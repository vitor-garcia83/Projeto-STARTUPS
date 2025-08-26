# backend/app/models.py
from django.db import models

class Usuario(models.Model):
    nome = models.CharField(max_length=100)
    email = models.EmailField(unique=True)
    senha_hash = models.CharField(max_length=255)
    telefone = models.CharField(max_length=20, blank=True, null=True)
    endereco = models.TextField(blank=True, null=True)
    tipo_usuario = models.CharField(max_length=20, choices=[
        ('cliente', 'Cliente'),
        ('prestador', 'Prestador'),
        ('admin', 'Admin')
    ])
    cpf = models.CharField(max_length=14, unique=True, null=True, blank=True)
    cnpj = models.CharField(max_length=18, unique=True, null=True, blank=True)
    foto_perfil = models.TextField(null=True, blank=True)
    criado_em = models.DateTimeField(auto_now_add=True)
    atualizado_em = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.nome
