package br.com.radar.auth;

import br.com.radar.user.UserRepository;
import org.springframework.stereotype.Service;

@Service
public class SocialAuthService {
  private final SupabaseIdentityVerifier verifier;
  private final IdentityRepository users;
  private final AuthService auth;
  private final UserRepository data;

  public SocialAuthService(
      SupabaseIdentityVerifier verifier,
      IdentityRepository users,
      AuthService auth,
      UserRepository data) {
    this.verifier = verifier;
    this.users = users;
    this.auth = auth;
    this.data = data;
  }

  public AuthModels.Tokens login(String accessToken, String anonymous) {
    var identity = verifier.verify(accessToken);
    String user = users.social(identity.uid(), identity.email(), identity.name(), anonymous);
    data.mergeAnonymous(anonymous, user);
    return auth.issueFor(user);
  }

  public void link(String user, String accessToken) {
    var identity = verifier.verify(accessToken);
    users.linkSocial(user, identity.uid(), identity.email());
  }
}
