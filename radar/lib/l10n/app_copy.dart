import 'package:material_ui/material_ui.dart';

import '../utils/format.dart' as format;

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
  String tr(String text, [Map<String, Object?> values = const {}]) {
    final match = _translations[text];
    final localized = match == null
        ? text
        : switch (Localizations.maybeLocaleOf(this)?.languageCode) {
            'en' => match.$1,
            'es' => match.$2,
            _ => text,
          };
    if (values.isEmpty) return localized;
    return localized.replaceAllMapped(RegExp(r'\{(\w+)\}'),
        (slot) => values[slot[1]]?.toString() ?? slot[0]!);
  }

  String newsGreeting(String name, {DateTime? now}) {
    final hour = (now ?? DateTime.now()).hour;
    final greeting = tr(hour < 12
        ? 'Bom dia'
        : hour < 18
            ? 'Boa tarde'
            : 'Boa noite');
    return '$greeting, $name';
  }

  String newsTime(DateTime time, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final age = today.difference(time);
    if (age.inMinutes < 1) return tr('agora');
    if (age.inMinutes < 60) return tr('há {n} min', {'n': age.inMinutes});
    if (format.isSameDay(time, today)) {
      return tr('há {n} h', {'n': age.inHours});
    }
    if (format.isSameDay(
        time, DateTime(today.year, today.month, today.day - 1))) {
      return tr('ontem às {time}', {
        'time': MaterialLocalizations.of(this)
            .formatTimeOfDay(TimeOfDay.fromDateTime(time))
      });
    }
    return MaterialLocalizations.of(this).formatShortDate(time);
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
  'O texto completo não está disponível no app.': (
    'The full text is unavailable in the app.',
    'El texto completo no está disponible en la app.'
  ),
  'Carregando o texto…': ('Loading the article…', 'Cargando el artículo…'),
  'Texto adaptado e traduzido.': (
    'Text adapted and translated.',
    'Texto adaptado y traducido.'
  ),
  'Texto adaptado para leitura.': (
    'Text adapted for reading.',
    'Texto adaptado para la lectura.'
  ),
  'Comentários': ('Comments', 'Comentarios'),
  'Curtir': ('Like', 'Me gusta'),
  'Descurtir': ('Unlike', 'Quitar Me gusta'),
  'Responder': ('Reply', 'Responder'),
  'Sua resposta': ('Your reply', 'Tu respuesta'),
  'Publicar resposta': ('Post reply', 'Publicar respuesta'),
  'Ver respostas ({n})': ('View replies ({n})', 'Ver respuestas ({n})'),
  'Ocultar respostas': ('Hide replies', 'Ocultar respuestas'),
  'Ver mais respostas': ('Load more replies', 'Ver más respuestas'),
  'As respostas também serão excluídas.': (
    'Replies will also be deleted.',
    'También se eliminarán las respuestas.'
  ),
  'Não foi possível carregar as respostas.': (
    'Could not load replies.',
    'No se pudieron cargar las respuestas.'
  ),
  'Não foi possível atualizar a curtida.': (
    'Could not update the like.',
    'No se pudo actualizar el Me gusta.'
  ),
  'O que você achou da notícia?': (
    'What did you think of the story?',
    '¿Qué te pareció la noticia?'
  ),
  'Entre com uma conta para comentar.': (
    'Sign in to comment.',
    'Inicia sesión para comentar.'
  ),
  'Publicar comentário': ('Post comment', 'Publicar comentario'),
  'Ainda não há comentários.': (
    'No comments yet.',
    'Todavía no hay comentarios.'
  ),
  'Ver mais comentários': ('Load more comments', 'Ver más comentarios'),
  'Leitor': ('Reader', 'Lector'),
  'Excluir': ('Delete', 'Eliminar'),
  'Excluir comentário': ('Delete comment', 'Eliminar comentario'),
  'Excluir comentário?': ('Delete this comment?', '¿Eliminar este comentario?'),
  'Não foi possível carregar os comentários.': (
    'Could not load comments.',
    'No se pudieron cargar los comentarios.'
  ),
  'Não foi possível publicar o comentário.': (
    'Could not post your comment.',
    'No se pudo publicar el comentario.'
  ),
  'Não foi possível excluir o comentário.': (
    'Could not delete the comment.',
    'No se pudo eliminar el comentario.'
  ),
  'Traduzindo…': ('Translating…', 'Traduciendo…'),
  'Tradução indisponível. Exibindo o original.': (
    'Translation unavailable. Showing the original.',
    'Traducción no disponible. Se muestra el original.',
  ),
  'Tentar de novo': ('Try again', 'Intentar de nuevo'),
  'Abrir no navegador': ('Open in browser', 'Abrir en el navegador'),
  'Texto publicado por {name}.': (
    'Text published by {name}.',
    'Texto publicado por {name}.',
  ),
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
  'Não foi possível carregar a publicação.': (
    'Could not load the publisher’s article.',
    'No se pudo cargar la publicación.'
  ),
  'Você pode tentar abrir o texto original.': (
    'You can try reading the original.',
    'Puedes intentar leer el original.'
  ),
  'Ver original': ('View original', 'Ver original'),
  'Traduzir página': ('Translate page', 'Traducir página'),
  'Publicado por {name}': ('Published by {name}', 'Publicado por {name}'),
  'Confirmado por {n} fontes · detectado às {time}': (
    'Confirmed by {n} sources · detected at {time}',
    'Confirmado por {n} fuentes · detectado a las {time}'
  ),
  'Rumor não confirmado · {n} fonte(s) até agora': (
    'Unconfirmed rumor · {n} source(s) so far',
    'Rumor sin confirmar · {n} fuente(s) hasta ahora'
  ),
  'Você soube {n} min antes da imprensa BR': (
    'You heard {n} min before the Brazilian press',
    'Te enteraste {n} min antes que la prensa brasileña'
  ),
  'Bom dia': ('Good morning', 'Buenos días'),
  'Boa tarde': ('Good afternoon', 'Buenas tardes'),
  'Boa noite': ('Good evening', 'Buenas noches'),
  'agora': ('now', 'ahora'),
  'há {n} min': ('{n} min ago', 'hace {n} min'),
  'há {n} h': ('{n} h ago', 'hace {n} h'),
  'ontem às {time}': ('yesterday at {time}', 'ayer a las {time}'),
  '{n} furo desde ontem à noite': (
    '{n} scoop since last night',
    '{n} primicia desde anoche'
  ),
  '{n} furos desde ontem à noite': (
    '{n} scoops since last night',
    '{n} primicias desde anoche'
  ),
  '{n} novas': ('{n} new', '{n} nuevas'),
  '{n} fontes · {min} min': (
    '{n} sources · {min} min',
    '{n} fuentes · {min} min'
  ),
  '{n} matérias': ('{n} articles', '{n} artículos'),
  '{n} matéria': ('{n} article', '{n} artículo'),
  '{n} hoje': ('{n} today', '{n} hoy'),
  '{n} min de leitura': ('{n} min read', '{n} min de lectura'),
  '{n} min restantes': ('{n} min left', '{n} min restantes'),
  '{n} dias': ('{n} days', '{n} días'),
  'Leitor desde {date}': ('Reader since {date}', 'Lector desde {date}'),
  'Nada encontrado pra “{query}”': (
    'Nothing found for “{query}”',
    'No se encontraron resultados para «{query}»'
  ),
  'Confira a conexão e tente de novo.': (
    'Check your connection and try again.',
    'Comprueba la conexión e inténtalo de nuevo.'
  ),
  'Puxe pra tentar de novo.': (
    'Pull to try again.',
    'Desliza hacia abajo para reintentar.'
  ),
  'Sem conexão. Mostrando as últimas notícias salvas.': (
    'Offline. Showing the latest saved news.',
    'Sin conexión. Mostrando las últimas noticias guardadas.'
  ),
  'Essa matéria saiu do ar': (
    'This article is unavailable',
    'Este artículo no está disponible'
  ),
  'Volte pro feed pra ver as últimas notícias.': (
    'Return to the feed for the latest news.',
    'Vuelve al feed para ver las últimas noticias.'
  ),
  'Nada por aqui ainda': ('Nothing here yet', 'Aún no hay nada aquí'),
  'Nada novo por aqui': ('Nothing new here', 'No hay novedades'),
  'Puxe o feed pra atualizar.': (
    'Pull to refresh the feed.',
    'Desliza para actualizar el feed.'
  ),
  'A IA avisa assim que surgir algo confirmado.': (
    'We’ll alert you when there’s a confirmed story.',
    'Te avisaremos cuando haya una noticia confirmada.'
  ),
  'Pessoas em destaque': ('People in the news', 'Personas destacadas'),
  'Empresas, pessoas e tópicos': (
    'Companies, people, and topics',
    'Empresas, personas y temas'
  ),
  'Matérias': ('Articles', 'Artículos'),
  'Tópicos': ('Topics', 'Temas'),
  'Pessoas': ('People', 'Personas'),
  'Buscas recentes': ('Recent searches', 'Búsquedas recientes'),
  'Limpar': ('Clear', 'Borrar'),
  'Tente o nome de uma empresa, pessoa ou tópico.': (
    'Try a company, person, or topic.',
    'Prueba con una empresa, persona o tema.'
  ),
  'Tudo em dia': ('All caught up', 'Todo al día'),
  'Marcar como lidos': ('Mark as read', 'Marcar como leídos'),
  'Quando nossa IA confirmar um furo dos seus tópicos, ele aparece aqui.': (
    'Confirmed scoops on your topics will appear here.',
    'Las primicias confirmadas de tus temas aparecerán aquí.'
  ),
  'Compartilhar furo': ('Share article', 'Compartir artículo'),
  'Link copiado': ('Link copied', 'Enlace copiado'),
  'Agora não': ('Not now', 'Ahora no'),
  'Curtindo o news.dev?': ('Enjoying news.dev?', '¿Te gusta news.dev?'),
  'Comunidade news.dev': ('news.dev community', 'Comunidad news.dev'),
  'URGENTE · AGORA': ('BREAKING · NOW', 'URGENTE · AHORA'),
  'Voltar para entrar': ('Back to sign in', 'Volver a iniciar sesión'),
  'ou': ('or', 'o'),
  'Já tenho conta': ('I already have an account', 'Ya tengo una cuenta'),
  'Tecnologia, antes de todo mundo.': (
    'Technology news before everyone else.',
    'Tecnología antes que nadie.'
  ),
  'O que te interessa?': ('What are you interested in?', '¿Qué te interesa?'),
  'Escolha 3 ou mais. Seu feed se ajusta ao que você lê.': (
    'Pick 3 or more. Your feed adapts to what you read.',
    'Elige 3 o más. Tu feed se adapta a lo que lees.'
  ),
  'Quantos alertas você quer?': (
    'How many alerts do you want?',
    '¿Cuántas alertas quieres?'
  ),
  'Você controla o barulho. Dá pra mudar a qualquer momento.': (
    'You control your notifications and can change them any time.',
    'Tú controlas las alertas y puedes cambiarlas cuando quieras.'
  ),
  'Silêncio das 23h às 7h': (
    'Quiet hours: 11 pm to 7 am',
    'Silencio de 23 h a 7 h'
  ),
  'Seja o primeiro a saber': (
    'Be the first to know',
    'Sé el primero en enterarte'
  ),
  'Ativar notificações': ('Enable notifications', 'Activar notificaciones'),
  'Resumo da manhã': ('Morning digest', 'Resumen de la mañana'),
  'À frente da imprensa BR, em média': (
    'Ahead of the Brazilian press, on average',
    'Por delante de la prensa brasileña, en promedio'
  ),
  'à frente da imprensa BR, em média': (
    'ahead of the Brazilian press, on average',
    'por delante de la prensa brasileña, en promedio'
  ),
  'furos antes de todo mundo': (
    'scoops before everyone else',
    'primicias antes que nadie'
  ),
  'Salvo pra ler depois': ('Saved for later', 'Guardado para más tarde'),
  'Removido dos salvos': (
    'Removed from saved articles',
    'Quitado de guardados'
  ),
  'Não foi possível abrir a página.': (
    'Could not open the page.',
    'No se pudo abrir la página.'
  ),
  'Saindo…': ('Signing out…', 'Cerrando sesión…'),
  'Lida': ('Read', 'Leído'),
  'Salve matérias pra ler depois': (
    'Save articles to read later',
    'Guarda artículos para leer después'
  ),
  'O que você terminar de ler fica aqui': (
    'Finished articles appear here',
    'Los artículos leídos aparecen aquí'
  ),
  'Tópicos atualizados': ('Topics updated', 'Temas actualizados'),
  'Salvar tópicos': ('Save topics', 'Guardar temas'),
  'Crie sua conta para escolher seus interesses e montar seu feed.': (
    'Create an account to select your interests and build your feed.',
    'Crea una cuenta para elegir tus intereses y crear tu feed.'
  ),
  'Entre para continuar e personalizar suas notícias.': (
    'Sign in to continue and personalize your news.',
    'Inicia sesión para continuar y personalizar tus noticias.'
  ),
  'Siga tópicos pra montar este feed': (
    'Follow topics to build this feed',
    'Sigue temas para crear este feed'
  ),
  'Escolha o que te interessa e a gente avisa primeiro.': (
    'Choose what interests you and we’ll keep you updated.',
    'Elige tus intereses y te mantendremos al tanto.'
  ),
  'Puxe pra atualizar. A IA segue vasculhando as fontes.': (
    'Pull to refresh while we check the sources.',
    'Desliza para actualizar mientras revisamos las fuentes.'
  ),
  'Rumores aparecem no feed com o aviso “não confirmado”.': (
    'Rumors appear in the feed with an “unconfirmed” label.',
    'Los rumores aparecen con la etiqueta «sin confirmar».'
  ),
  'A velocidade não pode custar credibilidade. Rumores ficam escondidos.': (
    'Rumors are hidden from the feed.',
    'Los rumores se ocultan del feed.'
  ),
  'Modelos, agentes, pesquisa e regulação.': (
    'Models, agents, research, and regulation.',
    'Modelos, agentes, investigación y regulación.'
  ),
  'Ataques, vazamentos, falhas e correções.': (
    'Attacks, leaks, vulnerabilities, and fixes.',
    'Ataques, filtraciones, fallos y correcciones.'
  ),
  'Linguagens, ferramentas e open source.': (
    'Languages, tools, and open source.',
    'Lenguajes, herramientas y código abierto.'
  ),
  'Chips e hardware': ('Chips and hardware', 'Chips y hardware'),
  'GPUs, fábricas, semicondutores e data centers.': (
    'GPUs, factories, semiconductors, and data centers.',
    'GPU, fábricas, semiconductores y centros de datos.'
  ),
  'Tech no Brasil': ('Tech in Brazil', 'Tecnología en Brasil'),
  'Foguetes, satélites e exploração espacial.': (
    'Rockets, satellites, and space exploration.',
    'Cohetes, satélites y exploración espacial.'
  ),
  'Rodadas, aquisições e quem está crescendo.': (
    'Funding, acquisitions, and growing companies.',
    'Financiación, adquisiciones y empresas en crecimiento.'
  ),
  'Celulares, wearables e lançamentos.': (
    'Phones, wearables, and launches.',
    'Móviles, wearables y lanzamientos.'
  ),
  'Consoles, estúdios e a indústria de jogos.': (
    'Consoles, studios, and the gaming industry.',
    'Consolas, estudios y la industria de videojuegos.'
  ),
  'Leis, governo e o que muda pra quem usa tecnologia.': (
    'Laws, government, and changes that affect tech users.',
    'Leyes, gobierno y cambios para quienes usan tecnología.'
  ),
  'Bitcoin, blockchain e ativos digitais.': (
    'Bitcoin, blockchain, and digital assets.',
    'Bitcoin, blockchain y activos digitales.'
  ),
  'Startups, governo e empresas brasileiras.': (
    'Brazilian startups, government, and companies.',
    'Startups, gobierno y empresas brasileñas.'
  ),
  'Editar perfil': ('Edit profile', 'Editar perfil'),
  'Adicionar foto': ('Add photo', 'Añadir foto'),
  'Trocar foto': ('Change photo', 'Cambiar foto'),
  'Remover foto': ('Remove photo', 'Eliminar foto'),
  'Sobre você': ('About you', 'Sobre ti'),
  'Perfil atualizado.': ('Profile updated.', 'Perfil actualizado.'),
  'Informe um nome válido.': (
    'Enter a valid name.',
    'Introduce un nombre válido.'
  ),
  'Não foi possível abrir a galeria.': (
    'Could not open your photos.',
    'No se pudo abrir la galería.'
  ),
  'Não foi possível salvar o perfil.': (
    'Could not save the profile.',
    'No se pudo guardar el perfil.'
  ),
  'Escolha uma imagem JPG ou PNG de até 256 KB.': (
    'Choose a JPG or PNG image up to 256 KB.',
    'Elige una imagen JPG o PNG de hasta 256 KB.',
  ),
};
