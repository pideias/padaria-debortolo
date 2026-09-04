using InfiniteCoffee2.Data;
using InfiniteCoffee2.Middleware;
using InfiniteCoffee2.Services;

namespace InfiniteCoffee2
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            var snapshotOnly = string.Equals(
                Environment.GetEnvironmentVariable("PADARIA_SNAPSHOT_ONLY"), "true", StringComparison.OrdinalIgnoreCase);
            if (!snapshotOnly)
            {
                Banco.Configurar(
                    Environment.GetEnvironmentVariable("PADARIA_CONNECTION_STRING") ??
                    builder.Configuration.GetConnectionString("DefaultConnection"));
            }

            builder.Services.AddControllersWithViews();
            builder.Services.AddSingleton<GoogleDriveSnapshotHostedService>();
            builder.Services.AddHostedService(provider => provider.GetRequiredService<GoogleDriveSnapshotHostedService>());
            builder.Services.AddHttpClient<GoogleDriveSnapshotStore>();
            builder.Services.AddCors(options =>
            {
                // O trabalho demonstrativo usa a API a partir do web, desktop e mobile.
                options.AddPolicy("FlutterDevelopment", policy => policy
                    .AllowAnyOrigin()
                    .AllowAnyHeader()
                    .AllowAnyMethod());
            });
            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen(options =>
            {
                options.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
                {
                    Title = "Infinite Coffee API",
                    Version = "v1",
                    Description = "API de controle de estoque da cafeteria."
                });
            });

            // Session é necessária para guardar os dados do atendimento entre as etapas
            builder.Services.AddSession(options =>
            {
                options.IdleTimeout = TimeSpan.FromMinutes(30);
                options.Cookie.HttpOnly = true;
                options.Cookie.IsEssential = true;
            });

            var app = builder.Build();

            // A estrutura de sync e criada na primeira operacao de banco. Isso permite
            // que o servidor suba em CI/desenvolvimento mesmo sem SQL Server disponivel;
            // a inicializacao continua idempotente quando a API realmente e usada.

            if (!app.Environment.IsDevelopment())
            {
                app.UseExceptionHandler("/Home/Error");
                app.UseHsts();
            }

            app.UseHttpsRedirection();
            app.UseStaticFiles();
            app.UseRouting();
            app.UseMiddleware<ApiKeyMiddleware>();
            app.UseCors("FlutterDevelopment");

            // Swagger fica disponível para o grupo testar as APIs durante o desenvolvimento.
            app.UseSwagger();
            app.UseSwaggerUI(options =>
            {
                options.SwaggerEndpoint("/swagger/v1/swagger.json", "Infinite Coffee API v1");
                options.RoutePrefix = "swagger";
            });

            app.UseAuthorization();

            // Habilita Session
            app.UseSession();

            app.MapControllerRoute(
                name: "default",
                pattern: "{controller=Home}/{action=Index}/{id?}");
            app.MapControllers();

            app.Run();

        }
    }
}
