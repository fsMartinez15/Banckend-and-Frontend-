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
import co.ridemove.adapter.out.SupabaseServiceAdapter;
import co.ridemove.adapter.out.WompiHttpAdapter;
import co.ridemove.application.PaymentService;
import co.ridemove.application.port.in.PaymentUseCases;
import co.ridemove.domain.PaymentSettings;
import java.net.http.HttpClient;
import java.time.Duration;

@Configuration
public class ApiConfiguration implements WebMvcConfigurer {
    private final String url,key,serviceKey;
    public ApiConfiguration(@Value("${ridemove.supabase-url}") String url,@Value("${ridemove.supabase-key}") String key,
                            @Value("${ridemove.supabase-service-key:}") String serviceKey) {
        this.url=url; this.key=key; this.serviceKey=serviceKey;
    }
    private RestClient.Builder client() {
        var factory=new JdkClientHttpRequestFactory(HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build());
        factory.setReadTimeout(Duration.ofSeconds(10));
        return RestClient.builder().baseUrl(url).requestFactory(factory).defaultHeader("apikey",key);
    }
    private static RestClient.Builder http(String base) {
        var factory=new JdkClientHttpRequestFactory(HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build());
        factory.setReadTimeout(Duration.ofSeconds(10));
        return RestClient.builder().baseUrl(base).requestFactory(factory);
    }
    /** Cliente con la clave secreta: solo en el servidor. Null si no está configurada. */
    @Bean SupabaseServiceAdapter supabaseServiceAdapter() {
        if (serviceKey==null || serviceKey.isBlank()) return new SupabaseServiceAdapter(null);
        var builder=http(url).defaultHeader("apikey",serviceKey);
        // Las claves heredadas (JWT) también van en Authorization; las nuevas sb_secret_ solo en apikey.
        if (serviceKey.startsWith("eyJ")) builder.defaultHeader("Authorization","Bearer "+serviceKey);
        return new SupabaseServiceAdapter(builder.build());
    }
    @Bean AuthUseCases authUseCases(SupabaseServiceAdapter service) {
        return new AuthService(new SupabaseIdentityAdapter(client().build()), service);
    }
    @Bean PaymentUseCases paymentUseCases(SupabaseServiceAdapter service,
            @Value("${ridemove.wompi.public-key:}") String publicKey,
            @Value("${ridemove.wompi.integrity-secret:}") String integrity,
            @Value("${ridemove.wompi.events-secret:}") String events,
            @Value("${ridemove.wompi.api-url:https://production.wompi.co/v1}") String apiUrl,
            @Value("${ridemove.wompi.checkout-url:https://checkout.wompi.co/p/}") String checkoutUrl,
            @Value("${ridemove.wompi.redirect-url:}") String redirectUrl,
            @Value("${ridemove.fare-cop:8000}") long fareCop) {
        var settings=new PaymentSettings(publicKey,integrity,events,checkoutUrl,redirectUrl,fareCop*100);
        return new PaymentService(service,new WompiHttpAdapter(http(apiUrl).build()),settings);
    }
    @Override public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new HandlerInterceptor() {
            @Override public boolean preHandle(HttpServletRequest request,HttpServletResponse response,Object handler) {
                if(request.getMethod().equals("OPTIONS")) return true;
                var authentication=(JwtAuthenticationToken) SecurityContextHolder.getContext().getAuthentication();
                var token=authentication.getToken();
                var client=client().defaultHeader("Authorization","Bearer "+token.getTokenValue()).build();
                var adapter=new SupabaseAdapter(client,token.getSubject());
                request.setAttribute("rideUseCases",new RideService(adapter,adapter,adapter,adapter,adapter));
                return true;
            }
        }).addPathPatterns("/api/**").excludePathPatterns("/api/auth/**","/api/payments/confirm","/api/payments/wompi/**");
    }
}
