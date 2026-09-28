package co.ridemove.bootstrap;

import co.ridemove.adapter.out.SupabaseAdapter;
import co.ridemove.application.RideService;
import jakarta.servlet.http.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;
import org.springframework.web.servlet.*;
import org.springframework.web.servlet.config.annotation.*;
import org.springframework.context.annotation.Bean;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import co.ridemove.application.AuthService;
import co.ridemove.application.port.in.AuthUseCases;
import co.ridemove.adapter.out.SupabaseIdentityAdapter;
import java.net.http.HttpClient;
import java.time.Duration;

@Configuration
public class ApiConfiguration implements WebMvcConfigurer {
    private final String url,key;
    public ApiConfiguration(@Value("${ridemove.supabase-url}") String url,@Value("${ridemove.supabase-key}") String key) {
        this.url=url; this.key=key;
    }
    private RestClient.Builder client() {
        var factory=new JdkClientHttpRequestFactory(HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build());
        factory.setReadTimeout(Duration.ofSeconds(10));
        return RestClient.builder().baseUrl(url).requestFactory(factory).defaultHeader("apikey",key);
    }
    @Bean AuthUseCases authUseCases() { return new AuthService(new SupabaseIdentityAdapter(client().build())); }
    @Override public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new HandlerInterceptor() {
            @Override public boolean preHandle(HttpServletRequest request,HttpServletResponse response,Object handler) {
                if(request.getMethod().equals("OPTIONS")) return true;
                var authentication=(JwtAuthenticationToken) SecurityContextHolder.getContext().getAuthentication();
                var token=authentication.getToken();
                var client=client().defaultHeader("Authorization","Bearer "+token.getTokenValue()).build();
                var adapter=new SupabaseAdapter(client,token.getSubject());
                request.setAttribute("rideUseCases",new RideService(adapter,adapter,adapter,adapter));
                return true;
            }
        }).addPathPatterns("/api/**").excludePathPatterns("/api/auth/**");
    }
}
