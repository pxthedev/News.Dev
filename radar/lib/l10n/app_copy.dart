import 'package:material_ui/material_ui.dart';

enum AppLanguage {
  portuguese('pt', 'Português', Locale('pt', 'BR')),
  english('en', 'English', Locale('en')),
  spanish('es', 'Español', Locale('es'));

  const AppLanguage(this.code, this.label, this.locale);
  final String code;
  final String label;
  final Locale locale;

  static AppLanguage fromCode(String? code) =>
      values.where((language) => language.code == code).firstOrNull ??
      portuguese;
}

extension AppCopy on BuildContext {
  String tr(String text) {
    final match = _translations[text];
    if (match == null) return text;
    return switch (Localizations.maybeLocaleOf(this)?.languageCode) {
      'en' => match.$1,
      'es' => match.$2,
      _ => text,
    };
  }
}

const _translations = <String, (String, String)>{
  'Agora': ('Now', 'Ahora'),
  'Explorar': ('Explore', 'Explorar'),
  'Salvos': ('Saved', 'Guardados'),
  'Perfil': ('Profile', 'Perfil'),
  'Idioma': ('Language', 'Idioma'),
  'Idioma do app': ('App language', 'Idioma de la app'),
  'Pra você': ('For you', 'Para ti'),
  'Urgente': ('Urgent', 'Urgente'),
  'Seguindo': ('Following', 'Siguiendo'),
  'Últimas': ('Latest', 'Últimas'),
  'Ver tudo': ('See all', 'Ver todo'),
  'Em alta agora': ('Trending now', 'En tendencia'),
  'Em alta hoje': ('Trending today', 'Tendencias de hoy'),
  'Buscar': ('Search', 'Buscar'),
  'Fechar': ('Close', 'Cerrar'),
  'Cancelar': ('Cancel', 'Cancelar'),
  'Continuar': ('Continue', 'Continuar'),
  'Começar': ('Get started', 'Comenzar'),
  'Entrar': ('Sign in', 'Iniciar sesión'),
  'Entrar no news.dev': ('Sign in to news.dev', 'Iniciar sesión en news.dev'),
  'Criar conta': ('Create account', 'Crear cuenta'),
  'Continuar com Google': ('Continue with Google', 'Continuar con Google'),
  'Continuar com Apple': ('Continue with Apple', 'Continuar con Apple'),
  'Sair da conta': ('Sign out', 'Cerrar sesión'),
  'Esqueci minha senha': ('Forgot my password', 'Olvidé mi contraseña'),
  'Senha': ('Password', 'Contraseña'),
  'Nome': ('Name', 'Nombre'),
  'Email': ('Email', 'Correo electrónico'),
  'Salvar': ('Save', 'Guardar'),
  'Compartilhar': ('Share', 'Compartir'),
  'Remover dos salvos': ('Remove from saved', 'Quitar de guardados'),
  'Voltar': ('Back', 'Atrás'),
  'Sinopse': ('Synopsis', 'Sinopsis'),
  'Ler matéria completa': ('Read full article', 'Leer el artículo completo'),
  'Recolher matéria': ('Collapse article', 'Contraer artículo'),
  'Matéria completa': ('Full article', 'Artículo completo'),
  'Fontes': ('Sources', 'Fuentes'),
  'Trecho disponível': ('Available excerpt', 'Fragmento disponible'),
  'Ler trecho disponível': (
    'Read available excerpt',
    'Leer fragmento disponible'
  ),
  'Fechar trecho': ('Close excerpt', 'Cerrar fragmento'),
  'A fonte disponibilizou apenas um trecho.': (
    'The publisher supplied an excerpt.',
    'El medio proporcionó un fragmento.',
  ),
  'Traduzindo…': ('Translating…', 'Traduciendo…'),
  'Tradução indisponível. Exibindo o original.': (
    'Translation unavailable. Showing the original.',
    'Traducción no disponible. Se muestra el original.',
  ),
  'Tentar de novo': ('Try again', 'Intentar de nuevo'),
  'Ler depois': ('Read later', 'Leer más tarde'),
  'Lidos': ('Read', 'Leídos'),
  'Alertas': ('Alerts', 'Alertas'),
  'NOTIFICAÇÕES': ('NOTIFICATIONS', 'NOTIFICACIONES'),
  'CONTA': ('ACCOUNT', 'CUENTA'),
  'Gerenciar conta': ('Manage account', 'Gestionar cuenta'),
  'Entrar ou criar conta': (
    'Sign in or create an account',
    'Iniciar sesión o crear una cuenta'
  ),
  'Tópicos seguidos': ('Followed topics', 'Temas seguidos'),
  'Comunidade': ('Community', 'Comunidad'),
  'Em breve': ('Coming soon', 'Próximamente'),
  'Configurações': ('Settings', 'Configuración'),
  'Mais opções': ('More options', 'Más opciones'),
  'Urgentes': ('Urgent alerts', 'Alertas urgentes'),
  'Resumo 8h e 19h': ('Digest at 8 am and 7 pm', 'Resumen a las 8 y 19 h'),
  'Rumores não confirmados': ('Unconfirmed rumors', 'Rumores sin confirmar'),
  'Desfazer': ('Undo', 'Deshacer'),
  'Copiar link': ('Copy link', 'Copiar enlace'),
  'Primeiro no Brasil': ('First in Brazil', 'Primero en Brasil'),
  'não confirmado': ('unconfirmed', 'sin confirmar'),
  'Ao vivo': ('Live', 'En directo'),
  'Escolher tópicos': ('Choose topics', 'Elegir temas'),
  'Sua vantagem': ('Your lead', 'Tu ventaja'),
  'Você está em dia.': ('You’re all caught up.', 'Estás al día.'),
  'Atualizando…': ('Updating…', 'Actualizando…'),
  'Sua semana': ('Your week', 'Tu semana'),
  'Arquivar': ('Archive', 'Archivar'),
  'Editar tópicos': ('Edit topics', 'Editar temas'),
  'Notícias': ('News', 'Noticias'),
  'Tudo': ('All', 'Todo'),
  'Marcar tudo como lido': ('Mark all as read', 'Marcar todo como leído'),
  'Escolha seus interesses': ('Choose your interests', 'Elige tus intereses'),
  'Mostrar senha': ('Show password', 'Mostrar contraseña'),
  'Ocultar senha': ('Hide password', 'Ocultar contraseña'),
  'Confirmar senha': ('Confirm password', 'Confirmar contraseña'),
  'Recuperar senha': ('Reset password', 'Recuperar contraseña'),
  'NOTÍCIAS DE TECNOLOGIA': ('TECHNOLOGY NEWS', 'NOTICIAS DE TECNOLOGÍA'),
  'Sua conta': ('Your account', 'Tu cuenta'),
  'Criar sua conta': ('Create your account', 'Crea tu cuenta'),
  'Criar nova senha': ('Create a new password', 'Crear una contraseña nueva'),
  'Informe seu nome.': ('Enter your name.', 'Introduce tu nombre.'),
  'Informe um email válido.': (
    'Enter a valid email address.',
    'Introduce un correo válido.'
  ),
  'Informe sua senha.': ('Enter your password.', 'Introduce tu contraseña.'),
  'Use pelo menos 8 caracteres.': (
    'Use at least 8 characters.',
    'Usa al menos 8 caracteres.'
  ),
  'As senhas não coincidem.': (
    'Passwords do not match.',
    'Las contraseñas no coinciden.'
  ),
  'Vincular Google': ('Link Google', 'Vincular Google'),
  'Vincular Apple': ('Link Apple', 'Vincular Apple'),
  'PRÉVIAS (DEV)': ('PREVIEWS (DEV)', 'VISTAS PREVIAS (DEV)'),
  'Telas fora do app e pop-ups': (
    'System screens and pop-ups',
    'Pantallas del sistema y ventanas emergentes'
  ),
  'Refazer onboarding': ('Restart setup', 'Reiniciar configuración'),
  'Segurança': ('Security', 'Seguridad'),
  'Inteligência Artificial': (
    'Artificial Intelligence',
    'Inteligencia artificial'
  ),
  'Programação': ('Programming', 'Programación'),
  'Regulação': ('Regulation', 'Regulación'),
  'Espaço': ('Space', 'Espacio'),
  'Cripto': ('Crypto', 'Cripto'),
  'Tecnologia': ('Technology', 'Tecnología'),
  'Área de dados': ('Data and analytics', 'Datos y analítica'),
  'Análise de dados, SQL, BI, engenharia de dados e carreira.': (
    'Data analysis, SQL, BI, data engineering, and careers.',
    'Análisis de datos, SQL, BI, ingeniería de datos y carreras.',
  ),
};
